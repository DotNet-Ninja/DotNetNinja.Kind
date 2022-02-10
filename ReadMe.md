# DotNetNinja.Kind
Misc Scripts/Config for managing Kind clusters locally

## Getting Started
* Clone Repo
* From Root of Repository
  * Import-Module .\powershell\DotNetNinja.Kind.psd1
  * Resolve-Path .\configs\v1.21.1\ | Set-KindConfigPath
* Check Dependencies
  * Test-KindDependencies
  * This will display where the required dependenciesare installed/running.
    * If you are not installing ArgoCD then you can igore the ArgoCD Dependency

## Creating a cluster
New-KindCluster - Will install a 3 node cluster with nginx ingress.




