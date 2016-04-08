using System;
using System.Collections.Generic;
using System.Text;
using Microsoft.Deployment.WindowsInstaller;
using System.Runtime.InteropServices;
using System.Runtime.InteropServices.ComTypes;

namespace EnableQuickEditCustomAction
{
    public class CustomActions
    {
        [CustomAction]
        public static ActionResult EnableQuickEdit(Session session)

//   public bool MakeShortcutElevated(string file_)
          {
           if (!System.IO.File.Exists(file_)) { return  ActionResult.Failure; }

           IPersistFile pf = new ShellLink() as IPersistFile;
           if (pf == null) { return ActionResult.Failure; }

           pf.Load(file_, 2 /* STGM_READWRITE */);
           IShellLinkDataList sldl = pf as IShellLinkDataList;
           if (sldl == null) { return ActionResult.Failure; }

           uint dwFlags;
           //sldl.GetFlags(out dwFlags);
           //sldl.SetFlags(dwFlags | 0x00002000 /* SLDF_RUNAS_USER */);
           pf.Save(null, true);
           return  ActionResult.Success;
          }
         }

 [ComImport(), Guid("00021401-0000-0000-C000-000000000046")]
 public class ShellLink { }

 [ComImport(), InterfaceType(ComInterfaceType.InterfaceIsIUnknown), Guid("45e2b4ae-b1c3-11d0-b92f-00a0c90312e1")]
 interface IShellLinkDataList
 {
  void AddDataBlock(IntPtr pDataBlock);
  void CopyDataBlock(uint dwSig, out IntPtr ppDataBlock);
  void RemoveDataBlock(uint dwSig);
  void GetFlags(out uint pdwFlags);
  void SetFlags(uint dwFlags);
 }

    }
}
