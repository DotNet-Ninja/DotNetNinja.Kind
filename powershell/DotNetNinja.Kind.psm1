function Test-KindDependencies{
    $status = [PSCustomObject]@{
        Kind = ($null -ne (where.exe kind)) 
        Kubectl = ($null -ne (where.exe kubectl)) 
        ArgoCD = ($null -ne (where.exe argocd)) 
        Docker = (Get-Service com.docker.service).Status -eq "Running"
    }

    return $status
}

function Set-KindConfigPath {
    param (
        [Parameter(Mandatory=$true, Position=0, ValueFromPipeline=$true)]
        [string]$Path
    )
    
    [System.Environment]::SetEnvironmentVariable('KindConfigPath', $Path, 'Machine')
    RefreshEnv.cmd
}

function Get-KindConfigPath{
    [Environment]::GetEnvironmentVariable('KindConfigPath', 'Machine')
}

function Resolve-KindConfigFile{
    param(
        [Parameter(Mandatory=$true, Position=0, ValueFromPipeline=$true)]
        [string]$Name
    )

    $configPath = Get-KindConfigPath
    return [System.IO.Path]::Combine($configPath, $Name)
}

function New-KindCluster{
    $clusterConfig = Resolve-KindConfigFile cluster.config.yaml
    $ingressConfig = Resolve-KindConfigFile ingress.yaml

    kind create cluster --config $clusterConfig
    Write-Output ""
    Write-Output "Adding Nginx Ingress Controller"
    kubectl apply -f $ingressConfig

    Write-Output ""
    Write-Output "Waiting for Ingress Controller to reach ready state."
    kubectl wait --for=condition=Ready pod -l app.kubernetes.io/component=controller -n ingress-nginx --timeout=300s
    kubectl wait --for=condition=Complete job -l app.kubernetes.io/component=admission-webhook -n ingress-nginx --timeout=300s
}

function Remove-KindCluster{
    kind delete cluster
}

function Install-ArgoCD{
    Write-Output "Creating Namespace 'argocd'"
    kubectl create namespace argocd
    Write-Output "Installing ArgoCD into Namespace 'argocd'"
    $manifest = Resolve-KindConfigFile ..\argocd\argo.install.yaml # Downloaded From: https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml & patched with --insecure flag
    kubectl apply -f $manifest -n argocd
    Write-Output "Adding Ingress for ArgoCD - argocd.dev-k8s.cloud"
    $ingress = Resolve-KindConfigFile ..\argocd\argo.ingress.yaml
    kubectl apply -f $ingress -n argocd
    
    Write-Output ""
    Write-Output "Waiting for pods to reach ready state."
    kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s
    kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=argocd-application-controller -n argocd --timeout=300s
    kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=argocd-dex-server -n argocd --timeout=300s
    kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=argocd-redis -n argocd --timeout=300s
    kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=argocd-repo-server -n argocd --timeout=300s
    Start-Process http://argocd.dev-k8s.cloud    
}

function Get-ArgoCDInitialAdminCredentials{
    param(
        [switch]$SetClipboard,
        [switch]$SuppressOutput
    )
    $secretValue = kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}"
    $password = Get-Base64Decoded($secretValue)
    if($SetClipboard.IsPresent){
        Set-Clipboard $password
        Write-Output "Password Copied"
    }
    if($SuppressOutput.IsPresent) {
        return
    }
    Write-Output $password
}

function Get-Base64Decoded{
    param(
        [Parameter(Mandatory=$true, Position=0, ValueFromPipeline=$true)]
        [string]$Encoded
    )
    return [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($Encoded))
}

Export-ModuleMember -Function Set-KindConfigPath
Export-ModuleMember -Function Get-KindConfigPath
Export-ModuleMember -Function Resolve-KindConfigFile
Export-ModuleMember -Function New-KindCluster
Export-ModuleMember -Function Remove-KindCluster
Export-ModuleMember -Function Install-ArgoCD
Export-ModuleMember -Function Get-ArgoCDInitialAdminCredentials
Export-ModuleMember -Function Test-KindDependencies