{$region 'constants'}
const
// Max length of short section name.
  IMAGE_SIZEOF_SHORT_NAME = 8;

// 3.1 Section Flags
// The section flags in the Characteristics field of the section
// header indicate characteristics of the section.
const
                                 // = $00000000;  //	Reserved for future use.
                                 //	= $00000001;  //  Reserved for future use.
                                 //	= $00000002;  //  Reserved for future use.
                                 // = $00000004;  //  Reserved for future use.
  IMAGE_SCN_TYPE_NO_PAD	            = $00000008;  //	The section should not be padded to the next boundary.
                                                  //  This flag is obsolete and is replaced by
                                                  //  IMAGE_SCN_ALIGN_1BYTES. This is valid only for object files.
                                 // = $00000010	  //  Reserved for future use.
  IMAGE_SCN_CNT_CODE	              = $00000020;  //	The section contains executable code.
  IMAGE_SCN_CNT_INITIALIZED_DATA	  = $00000040;  //	The section contains initialized data.
  IMAGE_SCN_CNT_UNINITIALIZED_DATA  = $00000080;  //	The section contains uninitialized data.
  IMAGE_SCN_LNK_OTHER	              = $00000100;  //	Reserved for future use.
  IMAGE_SCN_LNK_INFO	              = $00000200;  //	The section contains comments or other information.
                                                  //  The .drectve section has this type. This is valid for object files only.
                                //  = $00000400	  //  Reserved for future use.
  IMAGE_SCN_LNK_REMOVE	            = $00000800;  //	The section will not become part of the image. This is valid only for object files.
  IMAGE_SCN_LNK_COMDAT	            = $00001000;  //	The section contains COMDAT data.
  IMAGE_SCN_GPREL	                  = $00008000;  //	The section contains data referenced through the global pointer (GP).
  IMAGE_SCN_MEM_PURGEABLE	          = $00020000;  //	Reserved for future use.
  IMAGE_SCN_MEM_16BIT	              = $00020000;  //	For ARM machine types, the section contains Thumb code.
                                                  //  Reserved for future use with other machine types.
  IMAGE_SCN_MEM_LOCKED	            = $00040000;  //	Reserved for future use.
  IMAGE_SCN_MEM_PRELOAD	            = $00080000;  //	Reserved for future use.
  IMAGE_SCN_ALIGN_1BYTES	          = $00100000;  //	Align data on a 1-byte boundary. Valid only for object files.
  IMAGE_SCN_ALIGN_2BYTES	          = $00200000;  //	Align data on a 2-byte boundary. Valid only for object files.
  IMAGE_SCN_ALIGN_4BYTES	          = $00300000;  //	Align data on a 4-byte boundary. Valid only for object files.
  IMAGE_SCN_ALIGN_8BYTES	          = $00400000;  //	Align data on an 8-byte boundary. Valid only for object files.
  IMAGE_SCN_ALIGN_16BYTES	          = $00500000;  //	Align data on a 16-byte boundary. Valid only for object files.
  IMAGE_SCN_ALIGN_32BYTES	          = $00600000;  //	Align data on a 32-byte boundary. Valid only for object files.
  IMAGE_SCN_ALIGN_64BYTES	          = $00700000;  //	Align data on a 64-byte boundary. Valid only for object files.
  IMAGE_SCN_ALIGN_128BYTES	        = $00800000;  //	Align data on a 128-byte boundary. Valid only for object files.
  IMAGE_SCN_ALIGN_256BYTES	        = $00900000;  //	Align data on a 256-byte boundary. Valid only for object files.
  IMAGE_SCN_ALIGN_512BYTES	        = $00A00000;  //	Align data on a 512-byte boundary. Valid only for object files.
  IMAGE_SCN_ALIGN_1024BYTES	        = $00B00000;  //	Align data on a 1024-byte boundary. Valid only for object files.
  IMAGE_SCN_ALIGN_2048BYTES	        = $00C00000;  //	Align data on a 2048-byte boundary. Valid only for object files.
  IMAGE_SCN_ALIGN_4096BYTES	        = $00D00000;  //	Align data on a 4096-byte boundary. Valid only for object files.
  IMAGE_SCN_ALIGN_8192BYTES	        = $00E00000;  //	Align data on an 8192-byte boundary. Valid only for object files.
  IMAGE_SCN_LNK_NRELOC_OVFL	        = $01000000;  //	The section contains extended relocations.
  IMAGE_SCN_MEM_DISCARDABLE	        = $02000000;  //	The section can be discarded as needed.
  IMAGE_SCN_MEM_NOT_CACHED	        = $04000000;  //	The section cannot be cached.
  IMAGE_SCN_MEM_NOT_PAGED	          = $08000000;  //	The section is not pageable.
  IMAGE_SCN_MEM_SHARED	            = $10000000;  //	The section can be shared in memory.
  IMAGE_SCN_MEM_EXECUTE	            = $20000000;  //	The section can be executed as code.
  IMAGE_SCN_MEM_READ	              = $40000000;  //	The section can be read.
  IMAGE_SCN_MEM_WRITE	              = $80000000;  //	The section can be written to.
{$endregion 'constants'}
