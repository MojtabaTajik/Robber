{
  *
  * verrsrc.h -   Version Resource definitions
  *
  *               Include file declaring version resources in rc files
  *
  *               Copyright (c) Microsoft Corporation. All rights reserved.
  *
}

const

  (* ----- Symbols ----- *)
  // VS_FILE_INFO            = RT_VERSION;
  VS_VERSION_INFO = 1;
  VS_USER_DEFINED = 100;

  (* ----- VS_VERSION.dwFileFlags ----- *)
{$IFNDEF _MAC}
  VS_FFI_SIGNATURE = $FEEF04BD;
{$ELSE}
  VS_FFI_SIGNATURE = $BD04EFFE;
{$ENDIF}
  VS_FFI_STRUCVERSION  = $00010000;
  VS_FFI_FILEFLAGSMASK = $0000003F;

  (* ----- VS_VERSION.dwFileFlags ----- *)
  VS_FF_DEBUG        = $00000001;
  VS_FF_PRERELEASE   = $00000002;
  VS_FF_PATCHED      = $00000004;
  VS_FF_PRIVATEBUILD = $00000008;
  VS_FF_INFOINFERRED = $00000010;
  VS_FF_SPECIALBUILD = $00000020;

  (* ----- VS_VERSION.dwFileOS ----- *)
  VOS_UNKNOWN = $00000000;
  VOS_DOS     = $00010000;
  VOS_OS216   = $00020000;
  VOS_OS232   = $00030000;
  VOS_NT      = $00040000;
  VOS_WINCE   = $00050000;

  VOS__BASE      = $00000000;
  VOS__WINDOWS16 = $00000001;
  VOS__PM16      = $00000002;
  VOS__PM32      = $00000003;
  VOS__WINDOWS32 = $00000004;

  VOS_DOS_WINDOWS16 = $00010001;
  VOS_DOS_WINDOWS32 = $00010004;
  VOS_OS216_PM16    = $00020002;
  VOS_OS232_PM32    = $00030003;
  VOS_NT_WINDOWS32  = $00040004;

  (* ----- VS_VERSION.dwFileType ----- *)
  VFT_UNKNOWN    = $00000000;
  VFT_APP        = $00000001;
  VFT_DLL        = $00000002;
  VFT_DRV        = $00000003;
  VFT_FONT       = $00000004;
  VFT_VXD        = $00000005;
  VFT_STATIC_LIB = $00000007;

  (* ----- VS_VERSION.dwFileSubtype for VFT_WINDOWS_DRV ----- *)
  VFT2_UNKNOWN               = $00000000;
  VFT2_DRV_PRINTER           = $00000001;
  VFT2_DRV_KEYBOARD          = $00000002;
  VFT2_DRV_LANGUAGE          = $00000003;
  VFT2_DRV_DISPLAY           = $00000004;
  VFT2_DRV_MOUSE             = $00000005;
  VFT2_DRV_NETWORK           = $00000006;
  VFT2_DRV_SYSTEM            = $00000007;
  VFT2_DRV_INSTALLABLE       = $00000008;
  VFT2_DRV_SOUND             = $00000009;
  VFT2_DRV_COMM              = $0000000A;
  VFT2_DRV_INPUTMETHOD       = $0000000B;
  VFT2_DRV_VERSIONED_PRINTER = $0000000C;

  (* ----- VS_VERSION.dwFileSubtype for VFT_WINDOWS_FONT ----- *)
  VFT2_FONT_RASTER   = $00000001;
  VFT2_FONT_VECTOR   = $00000002;
  VFT2_FONT_TRUETYPE = $00000003;

  (* ----- VerFindFile() flags ----- *)
  VFFF_ISSHAREDFILE = $0001;

  VFF_CURNEDEST    = $0001;
  VFF_FILEINUSE    = $0002;
  VFF_BUFFTOOSMALL = $0004;

  (* ----- VerInstallFile() flags ----- *)
  VIFF_FORCEINSTALL  = $0001;
  VIFF_DONTDELETEOLD = $0002;

  VIF_TEMPFILE = $00000001;
  VIF_MISMATCH = $00000002;
  VIF_SRCOLD   = $00000004;

  VIF_DIFFLANG   = $00000008;
  VIF_DIFFCODEPG = $00000010;
  VIF_DIFFTYPE   = $00000020;

  VIF_WRITEPROT        = $00000040;
  VIF_FILEINUSE        = $00000080;
  VIF_OUTOFSPACE       = $00000100;
  VIF_ACCESSVIOLATION  = $00000200;
  VIF_SHARINGVIOLATION = $00000400;
  VIF_CANNOTCREATE     = $00000800;
  VIF_CANNOTDELETE     = $00001000;
  VIF_CANNOTRENAME     = $00002000;
  VIF_CANNOTDELETECUR  = $00004000;
  VIF_OUTOFMEMORY      = $00008000;

  VIF_CANNOTREADSRC = $00010000;
  VIF_CANNOTREADDST = $00020000;

  VIF_BUFFTOOSMALL      = $00040000;
  VIF_CANNOTLOADLZ32    = $00080000;
  VIF_CANNOTLOADCABINET = $00100000;

{$IFNDEF RC_INVOKED}              (* RC doesn't need to see the rest of this *)

  (*
    FILE_VER_GET_... flags are for use by
    GetFileVersionInfoSizeEx
    GetFileVersionInfoExW
  *)
  FILE_VER_GET_LOCALISED  = $01;
  FILE_VER_GET_NEUTRAL    = $02;
  FILE_VER_GET_PREFETCHED = $04;

  (* ----- Types and structures ----- *)

type
  tagVS_FIXEDFILEINFO = packed record
    dwSignature: uint32;        (* e.g. =$feef04bd *)
    dwStrucVersion: uint32;     (* e.g. =$00000042 = "0.42" *)
    dwFileVersionMS: uint32;    (* e.g. =$00030075 = "3.75" *)
    dwFileVersionLS: uint32;    (* e.g. =$00000031 = "0.31" *)
    dwProductVersionMS: uint32; (* e.g. =$00030010 = "3.10" *)
    dwProductVersionLS: uint32; (* e.g. =$00000031 = "0.31" *)
    dwFileFlagsMask: uint32;    (* = $3F for version "0.42" *)
    dwFileFlags: uint32;        (* e.g. VFF_DEBUG | VFF_PRERELEASE *)
    dwFileOS: uint32;           (* e.g. VOS_DOS_WINDOWS16 *)
    dwFileType: uint32;         (* e.g. VFT_DRIVER *)
    dwFileSubtype: uint32;      (* e.g. VFT2_DRV_KEYBOARD *)
    dwFileDateMS: uint32;       (* e.g. 0 *)
    dwFileDateLS: uint32;       (* e.g. 0 *)
  end;

  VS_FIXEDFILEINFO = tagVS_FIXEDFILEINFO;

{$ENDIF}  (* !RC_INVOKED *)

