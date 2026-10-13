; ============================================================================
;  B-Catalog - Script d'installation Inno Setup 6
;  Compilation : "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" installer.iss
; ============================================================================

#define MyAppName        "B-Catalog"
#define MyAppVersion     "1.0.0"
#define MyAppPublisher   "Geraud Software"
#define MyAppExeName     "boutique_catalog.exe"
#define MyBuildDir       "build\windows\x64\runner\Release"
#define MyAppIcon        "windows\runner\resources\app_icon.ico"

[Setup]
; AppId fixe : ne JAMAIS le modifier, c'est lui qui permet les mises a jour
; propres (remplacement en place) et une desinstallation correcte.
AppId={{5B20C996-5547-4CC7-AA78-ADE4EF1863F9}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
VersionInfoVersion={#MyAppVersion}
VersionInfoCompany={#MyAppPublisher}
VersionInfoProductName={#MyAppName}

; Dossier d'installation par defaut
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
UninstallDisplayName={#MyAppName}
UninstallDisplayIcon={app}\{#MyAppExeName}

; Application 64 bits uniquement (build x64)
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

; Sortie : un seul fichier compresse dans dist\
OutputDir=dist
OutputBaseFilename=BoutiqueCatalog_Setup
Compression=lzma2/ultra64
SolidCompression=yes
LZMAUseSeparateProcess=yes

; Interface moderne
WizardStyle=modern
SetupIconFile={#MyAppIcon}
PrivilegesRequired=admin
AllowNoIcons=yes

[Languages]
Name: "french"; MessagesFile: "compiler:Languages\French.isl"

[Files]
; Tout le contenu du build release, sous-dossiers compris (data\, flutter_assets\, ...)
Source: "{#MyBuildDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
; Menu Demarrer
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\{#MyAppExeName}"
; Bureau : toujours cree, sans case a cocher (obligatoire)
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\{#MyAppExeName}"

[Run]
; Proposer le lancement a la fin de l'installation
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
; Nettoyage des fichiers generes par l'application au runtime
Type: filesandordirs; Name: "{app}"
