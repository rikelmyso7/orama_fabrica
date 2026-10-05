#ifndef AppVersion
#define AppVersion "1.0.0"
#endif

[Setup]
; AppId fixo: é ele que faz o instalador novo atualizar a instalação existente em vez de duplicar.
AppId={{299F59F2-DA02-4B5E-AD92-BF58AAF1883A}
AppName=Orama Fabrica
AppVersion={#AppVersion}
AppPublisher=Rikelmy Roberto
AppPublisherURL=https://github.com/rikelmyso7
AppSupportURL=mailto:rikelmyroberto1@gmail.com
AppUpdatesURL=https://github.com/rikelmyso7/orama_fabrica/releases
DefaultDirName={autopf}\Orama Fabrica
DefaultGroupName=Orama Fabrica
AllowNoIcons=yes
SourceDir=..
OutputDir=installer
OutputBaseFilename=orama_fabrica_setup_{#AppVersion}
SetupIconFile=windows\runner\resources\app_icon.ico
Compression=lzma
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
CloseApplications=yes
CloseApplicationsFilter=orama_fabrica.exe
UninstallDisplayIcon={app}\orama_fabrica.exe

[Languages]
Name: "portuguesebr"; MessagesFile: "compiler:Languages\BrazilianPortuguese.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\Orama Fabrica"; Filename: "{app}\orama_fabrica.exe"
Name: "{group}\{cm:UninstallProgram,Orama Fabrica}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\Orama Fabrica"; Filename: "{app}\orama_fabrica.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\orama_fabrica.exe"; Description: "{cm:LaunchProgram,Orama Fabrica}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
Type: filesandordirs; Name: "{app}"
