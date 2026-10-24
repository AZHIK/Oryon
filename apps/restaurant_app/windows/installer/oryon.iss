; Oryon for Windows - Inno Setup script.
;
; The release pipeline (.github/workflows/windows-installer.yml) builds this
; after `flutter build windows --release`. To build an installer locally:
;
;   flutter build windows --release ^
;     --build-name=1.0.0 --build-number=1 ^
;     --dart-define=IDENTITY_API_BASE_URL=https://auth.oryonfoods.com/api/v1 ^
;     --dart-define=INVENTORY_API_BASE_URL=https://inventory.oryonfoods.com/api/v1 ^
;     --dart-define=POS_API_BASE_URL=https://pos.oryonfoods.com/api/v1
;   iscc /DAppVersion=1.0.0 /DAppBuild=1 windows\installer\oryon.iss
;
; The script expects the Flutter release bundle in
; build\windows\x64\runner\Release. If windows\installer\redist\vc_redist.x64.exe
; exists it is bundled and installed when the machine is missing the Visual C++
; runtime; otherwise that prerequisite is skipped.

#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif

#ifndef AppBuild
  #define AppBuild "0"
#endif

#define AppName "Oryon"
#define AppPublisher "Oryon Foods"
#define AppExeName "oryon.exe"
#define AppIdValue "C4A81DB3-0942-4C75-B12A-0EA9F0CFFEAB"

; Absolute-ish paths, relative to this script.
#define RepoAppDir AddBackslash(SourcePath) + "..\..\"
#define ReleaseDir RepoAppDir + "build\windows\x64\runner\Release"
#define VcRedistFile AddBackslash(SourcePath) + "redist\vc_redist.x64.exe"

[Setup]
; AppId is what Windows uses to recognise upgrades of the same product. Never
; change it between releases, or installed copies will not be upgraded in place.
AppId={{{#AppIdValue}}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher={#AppPublisher}
AppPublisherURL=https://oryonfoods.com
AppSupportURL=https://oryonfoods.com
AppUpdatesURL=https://oryonfoods.com
VersionInfoVersion={#AppVersion}.{#AppBuild}
VersionInfoCompany={#AppPublisher}
VersionInfoDescription={#AppName} Setup
VersionInfoProductName={#AppName}
VersionInfoProductVersion={#AppVersion}
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
PrivilegesRequired=admin
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir={#RepoAppDir}build\windows\installer
OutputBaseFilename=Oryon-{#AppVersion}-windows-x64-setup
SetupIconFile={#RepoAppDir}windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#AppExeName}
UninstallDisplayName={#AppName}
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
CloseApplications=yes
RestartApplications=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; Flutter's release bundle: oryon.exe, flutter_windows.dll, plugin DLLs,
; native assets, and data\ (app.so + flutter_assets).
Source: "{#ReleaseDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
#if FileExists(VcRedistFile)
Source: "{#VcRedistFile}"; DestDir: "{tmp}"; DestName: "vc_redist.x64.exe"; Flags: deleteafterinstall
#endif

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExeName}"
Name: "{group}\Uninstall {#AppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; Tasks: desktopicon

[Run]
#if FileExists(VcRedistFile)
Filename: "{tmp}\vc_redist.x64.exe"; Parameters: "/install /quiet /norestart"; StatusMsg: "Installing Microsoft Visual C++ runtime..."; Flags: waituntilterminated; Check: VcRedistMissing
#endif
Filename: "{app}\{#AppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(AppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[Code]
// Flutter desktop apps link against the Visual C++ runtime dynamically. Most
// Windows machines already have it; install it only when the registry says it
// is absent or broken.
function VcRedistMissing: Boolean;
var
  Installed: Cardinal;
begin
  Result :=
    (not RegQueryDWordValue(HKLM64,
      'SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64',
      'Installed', Installed)) or (Installed <> 1);
end;

// ---------------------------------------------------------------------------
// Uninstall: remove per-user application state.
//
// The app keeps its encrypted Drift database (app.db plus -wal/-shm) and its
// flutter_secure_storage key files in the application support directory,
// %APPDATA%\<CompanyName>\<ProductName>. Those two names come from Runner.rc,
// which is why AppDataSubDir must stay in sync with that file.
//
// Setup runs elevated, so {userappdata} can belong to the administrator who
// confirmed the UAC prompt rather than to the cashier account that actually
// used the app. Enumerate every local profile instead of deleting only one.
// ---------------------------------------------------------------------------
const
  AppDataSubDir = 'Oryon Foods\Oryon';

procedure DeleteAppDataUnder(const ProfilesRoot: String);
var
  FindRec: TFindRec;
  DataDir: String;
begin
  if not FindFirst(AddBackslash(ProfilesRoot) + '*', FindRec) then
    Exit;
  try
    repeat
      if (FindRec.Attributes and FILE_ATTRIBUTE_DIRECTORY) <> 0 then
      begin
        DataDir := AddBackslash(ProfilesRoot) + ExtractFileName(FindRec.Name) +
          '\AppData\Roaming\' + AppDataSubDir;
        if DirExists(DataDir) then
        begin
          Log('Deleting application data: ' + DataDir);
          DelTree(DataDir, True, True, True);
          // Removes the company folder too, but only if it is now empty.
          RemoveDir(ExtractFileDir(DataDir));
        end;
      end;
    until not FindNext(FindRec);
  finally
    FindClose(FindRec);
  end;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  ProfilesRoot: String;
  SystemUsersRoot: String;
begin
  if CurUninstallStep <> usPostUninstall then
    Exit;

  ProfilesRoot := ExtractFileDir(ExtractFileDir(ExtractFileDir(
    ExpandConstant('{userappdata}'))));
  DeleteAppDataUnder(ProfilesRoot);

  // Profiles may live on the system drive even when the uninstalling account
  // does not.
  SystemUsersRoot := ExpandConstant('{sd}\Users');
  if CompareText(ProfilesRoot, SystemUsersRoot) <> 0 then
    DeleteAppDataUnder(SystemUsersRoot);
end;
