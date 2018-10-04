## Script para automatizacion de agregado masivo de managers en grupos
## activando el campo de "Manager puede actualizar la lista", que requiere modificar la ACL
## Hernan Alvarez - https://hpalvarez.tech - Octubre 2018
## Basado en https://blogs.technet.microsoft.com/blur-lines_-powershell_-author_shirleym/2013/10/07/manager-can-update-membership-list-part-1/

Try
{
    $listaUsuarios = Import-Csv -Path .\managers.txt -Delimiter ";" -Encoding UTF8 -ErrorAction Stop
}
Catch
{
    Write-Output("**[ERROR]: ¡Archivo managers.txt no encontrado!")
    Break
}

## Formato de managers.txt:
## usuario;grupo
## usuario: el SamAccountName del usuario
## grupo: el grupo al que se le va a asignar dicho usuario como Manager

## Seteo de log

$archivoLog = ".\ManagedBy-Log.log"

## Loop principal

foreach($registro in $listaUsuarios)
{
    # Toma de datos del usuario

    Try
    {
        $nuevoManager = Get-ADUser $registro.usuario -Properties DistinguishedName -ErrorAction Stop
        $grupoManager = Get-ADGroup $registro.grupo -Properties DistinguishedName -ErrorAction Stop
    }
    Catch
    {
        Write-Output("**[ERROR]: ¡Datos de usuario o grupo incorrectos!")
        Add-Content -Path $archivoLog -Encoding UTF8 -Value ("**[ERROR]: Usuario " + $registro.usuario + " o grupo " + $registro.grupo + " incorrectos")
        Continue
    }
    $usuarioDN = $nuevoManager.DistinguishedName
    $grupoDN = $grupoManager.DistinguishedName

    # Preparacion de la ACL

    $guid =[guid]'bf9679c0-0de6-11d0-a285-00aa003049e2'
    # OJO: la proxima linea toma el dato del dominio en el que se corre el script, no sirve para correr en un dominio remoto
    $user = New-Object System.Security.Principal.NTAccount($env:userdomain + "\" + $nuevoManager.SamAccountName)
    $sid = $user.translate([System.Security.Principal.SecurityIdentifier])
    $acl = Get-Acl "ad:$grupoDN"
    $ctrl =[System.Security.AccessControl.AccessControlType]::Allow
    $rights =[System.DirectoryServices.ActiveDirectoryRights]::WriteProperty -bor[System.DirectoryServices.ActiveDirectoryRights]::ExtendedRight
    $intype =[System.DirectoryServices.ActiveDirectorySecurityInheritance]::None

    # Arma el objeto para aplicar la regla

    $group =[adsi]"LDAP://$grupoDN"
    $group.put("ManagedBy","$usuarioDN")
    $group.setinfo()

    # Crea la nueva regla y la aplica
    # http://msdn.microsoft.com/en-us/library/xh02bekw.aspx

    $rule = New-Object System.DirectoryServices.ActiveDirectoryAccessRule($sid,$rights,$ctrl,$guid)
    $acl.AddAccessRule($rule)
    Set-Acl -acl $acl -path "ad:$grupoDN"
    Write-Output("**[OK]: Usuario " + $nuevoManager.SamAccountName + " agregado como manager en el grupo " + $grupoManager.SamAccountName)
    Add-Content -Path $archivoLog -Encoding UTF8 -Value ("**[OK]: Usuario " + $nuevoManager.SamAccountName + " agregado como manager en el grupo " + $grupoManager.SamAccountName)
}
