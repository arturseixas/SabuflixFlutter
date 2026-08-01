[Setup]
AppName=Sabuflix
AppVersion=1.0.0
WizardStyle=modern
DefaultDirName={localappdata}\Sabuflix
DefaultGroupName=Sabuflix
OutputDir=..\dist
OutputBaseFilename=sabuflix-installer
Compression=lzma2/ultra64
SolidCompression=yes
UninstallDisplayIcon={app}\sabuflix.exe

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\Sabuflix"; Filename: "{app}\sabuflix.exe"
Name: "{autodesktop}\Sabuflix"; Filename: "{app}\sabuflix.exe"

[Run]
Filename: "{app}\sabuflix.exe"; Description: "Executar Sabuflix agora"; Flags: postinstall nowait skipifsilent
