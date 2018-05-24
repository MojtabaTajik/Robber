const
// 4.2.1. Type Indicators
// x64 Processors
// The following relocation type indicators are defined for x64 and compatible processors.
  IMAGE_REL_AMD64_ABSOLUTE	= $0000;  //  The relocation is ignored.
  IMAGE_REL_AMD64_ADDR64	  = $0001;  // 	The 64-bit VA of the relocation target.
  IMAGE_REL_AMD64_ADDR32	  = $0002;  // 	The 32-bit VA of the relocation target.
  IMAGE_REL_AMD64_ADDR32NB  = $0003;  // 	The 32-bit address without an image base (RVA).
  IMAGE_REL_AMD64_REL32	    = $0004;  // 	The 32-bit relative address from the byte following the relocation.
  IMAGE_REL_AMD64_REL32_1	  = $0005;  // 	The 32-bit address relative to byte distance 1 from the relocation.
  IMAGE_REL_AMD64_REL32_2	  = $0006;  // 	The 32-bit address relative to byte distance 2 from the relocation.
  IMAGE_REL_AMD64_REL32_3	  = $0007;  // 	The 32-bit address relative to byte distance 3 from the relocation.
  IMAGE_REL_AMD64_REL32_4	  = $0008;  // 	The 32-bit address relative to byte distance 4 from the relocation.
  IMAGE_REL_AMD64_REL32_5	  = $0009;  // 	The 32-bit address relative to byte distance 5 from the relocation.
  IMAGE_REL_AMD64_SECTION	  = $000A;  // 	The 16-bit section index of the section that contains the target.
                                      //  This is used to support debugging information.
  IMAGE_REL_AMD64_SECREL	  = $000B;  // 	The 32-bit offset of the target from the beginning of its section.
                                      //  This is used to support debugging information and static thread local storage.
  IMAGE_REL_AMD64_SECREL7	  = $000C;  // 	A 7-bit unsigned offset from the base of the section that contains the target.
  IMAGE_REL_AMD64_TOKEN	    = $000D;  // 	CLR tokens.
  IMAGE_REL_AMD64_SREL32  	= $000E;  // 	A 32-bit signed span-dependent value emitted into the object.
  IMAGE_REL_AMD64_PAIR	    = $000F;  // 	A pair that must immediately follow every span-dependent value.
  IMAGE_REL_AMD64_SSPAN32	  = $0010;  // 	A 32-bit signed span-dependent value that is applied at link time.

// ARM Processors
// The following relocation type indicators are defined for ARM processors.
  IMAGE_REL_ARM_ABSOLUTE	  = $0000;  // 	The relocation is ignored.
  IMAGE_REL_ARM_ADDR32	    = $0001;  // 	The 32-bit VA of the target.
  IMAGE_REL_ARM_ADDR32NB	  = $0002;  // 	The 32-bit RVA of the target.
  IMAGE_REL_ARM_BRANCH24	  = $0003;  // 	The most significant 24 bits of the signed 26-bit relative displacement of the target.  Applied to a B or BL instruction in ARM mode.
  IMAGE_REL_ARM_BRANCH11	  = $0004;  // 	The most significant 22 bits of the signed 23-bit relative displacement of the target.  Applied to a contiguous 16-bit B+BL pair in Thumb mode prior to ARMv7.
  IMAGE_REL_ARM_TOKEN	      = $0005;  // 	CLR tokens.
  IMAGE_REL_ARM_BLX24	      = $0008;  // 	The most significant 24 or 25 bits of the signed 26-bit relative displacement of the target.  Applied to an unconditional BL instruction in ARM mode.  The BL is transformed to a BLX during relocation if the target is in Thumb mode.
  IMAGE_REL_ARM_BLX11	      = $0009;  // 	The most significant 21 or 22 bits of the signed 23-bit relative displacement of the target.  Applied to a contiguous 16-bit B+BL pair in Thumb mode prior to ARMv7.  The BL is transformed to a BLX during relocation if the target is in ARM mode.
  IMAGE_REL_ARM_SECTION	    = $000E;  // 	The 16-bit section index of the section that contains the target. This is used to support debugging information.
  IMAGE_REL_ARM_SECREL	    = $000F;  // 	The 32-bit offset of the target from the beginning of its section. This is used to support debugging information and static thread local storage.
  IMAGE_REL_ARM_MOV32A	    = $0010;  // 	The 32-bit VA of the target.  Applied to a contiguous MOVW+MOVT pair in ARM mode.  The 32-bit VA is added to the existing value that is encoded in the immediate fields of the pair.
  IMAGE_REL_ARM_MOV32T	    = $0011;  // 	The 32-bit VA of the target.  Applied to a contiguous MOVW+MOVT pair in Thumb mode.  The 32-bit VA is added to the existing value that is encoded in the immediate fields of the pair.
  IMAGE_REL_ARM_BRANCH20T	  = $0012;  // 	The most significant 20 bits of the signed 21-bit relative displacement of the target.  Applied to a 32-bit conditional B instruction in Thumb mode.
  IMAGE_REL_ARM_BRANCH24T	  = $0014;  // 	The most significant 24 bits of the signed 25-bit relative displacement of the target.  Applied to a 32-bit unconditional B or BL instruction in Thumb mode.
  IMAGE_REL_ARM_BLX23T	    = $0015;  // 	The most significant 23 or 24 bits of the signed 25-bit relative displacement of the target.  Applied to a 32-bit BL instruction in Thumb mode.  The BL is transformed to a BLX during relocation if the target is in ARM mode.

  // Hitachi SuperH Processors
  // The following relocation type indicators are defined for SH3 and SH4 processors.
  // SH5-specific relocations are noted as SHM (SH Media).
  IMAGE_REL_SH3_ABSOLUTE	      = $0000;  // 	The relocation is ignored.
  IMAGE_REL_SH3_DIRECT16	      = $0001;  // 	A reference to the 16-bit location that contains the VA of the target symbol.
  IMAGE_REL_SH3_DIRECT32	      = $0002;  // 	The 32-bit VA of the target symbol.
  IMAGE_REL_SH3_DIRECT8	        = $0003;  // 	A reference to the 8-bit location that contains the VA of the target symbol.
  IMAGE_REL_SH3_DIRECT8_WORD	  = $0004;  // 	A reference to the 8-bit instruction that contains the effective 16-bit VA of the target symbol.
  IMAGE_REL_SH3_DIRECT8_LONG	  = $0005;  // 	A reference to the 8-bit instruction that contains the effective 32-bit VA of the target symbol.
  IMAGE_REL_SH3_DIRECT4	        = $0006;  // 	A reference to the 8-bit location whose low 4 bits contain the VA of the target symbol.
  IMAGE_REL_SH3_DIRECT4_WORD	  = $0007;  // 	A reference to the 8-bit instruction whose low 4 bits contain the effective 16-bit VA of the target symbol.
  IMAGE_REL_SH3_DIRECT4_LONG	  = $0008;  // 	A reference to the 8-bit instruction whose low 4 bits contain the effective 32-bit VA of the target symbol.
  IMAGE_REL_SH3_PCREL8_WORD	    = $0009;  // 	A reference to the 8-bit instruction that contains the effective 16-bit relative offset of the target symbol.
  IMAGE_REL_SH3_PCREL8_LONG	    = $000A;  // 	A reference to the 8-bit instruction that contains the effective 32-bit relative offset of the target symbol.
  IMAGE_REL_SH3_PCREL12_WORD	  = $000B;  // 	A reference to the 16-bit instruction whose low 12 bits contain the effective 16-bit relative offset of the target symbol.
  IMAGE_REL_SH3_STARTOF_SECTION	= $000C;  // 	A reference to a 32-bit location that is the VA of the section that contains the target symbol.
  IMAGE_REL_SH3_SIZEOF_SECTION	= $000D;  // 	A reference to the 32-bit location that is the size of the section that contains the target symbol.
  IMAGE_REL_SH3_SECTION	        = $000E;  // 	The 16-bit section index of the section that contains the target. This is used to support debugging information.
  IMAGE_REL_SH3_SECREL	        = $000F;  // 	The 32-bit offset of the target from the beginning of its section. This is used to support debugging information and static thread local storage.
  IMAGE_REL_SH3_DIRECT32_NB	    = $0010;  // 	The 32-bit RVA of the target symbol.
  IMAGE_REL_SH3_GPREL4_LONG	    = $0011;  // 	GP relative.
  IMAGE_REL_SH3_TOKEN	          = $0012;  // 	CLR token.
  IMAGE_REL_SHM_PCRELPT	        = $0013;  // 	The offset from the current instruction in longwords. If the NOMODE bit is not set, insert the inverse of the low bit at bit 32 to select PTA or PTB.
  IMAGE_REL_SHM_REFLO	          = $0014;  // 	The low 16 bits of the 32-bit address.
  IMAGE_REL_SHM_REFHALF	        = $0015;  // 	The high 16 bits of the 32-bit address.
  IMAGE_REL_SHM_RELLO 	        = $0016;  // 	The low 16 bits of the relative address.
  IMAGE_REL_SHM_RELHALF	        = $0017;  // 	The high 16 bits of the relative address.
  IMAGE_REL_SHM_PAIR  	        = $0018;  // 	The relocation is valid only when it immediately follows a REFHALF, RELHALF, or RELLO relocation. The SymbolTableIndex field of the relocation contains a displacement and not an index into the symbol table.
  IMAGE_REL_SHM_NOMODE	        = $8000;  // 	The relocation ignores section mode.

  // IBM PowerPC Processors
  // The following relocation type indicators are defined for PowerPC processors.
  IMAGE_REL_PPC_ABSOLUTE	= $0000;  // 	The relocation is ignored.
  IMAGE_REL_PPC_ADDR64	  = $0001;  // 	The 64-bit VA of the target.
  IMAGE_REL_PPC_ADDR32	  = $0002;  // 	The 32-bit VA of the target.
  IMAGE_REL_PPC_ADDR24	  = $0003;  // 	The low 24 bits of the VA of the target. This is valid only when the target symbol is absolute and can be sign-extended to its original value.
  IMAGE_REL_PPC_ADDR16	  = $0004;  // 	The low 16 bits of the target’s VA.
  IMAGE_REL_PPC_ADDR14	  = $0005;  // 	The low 14 bits of the target’s VA. This is valid only when the target symbol is absolute and can be sign-extended to its original value.
  IMAGE_REL_PPC_REL24	    = $0006;  // 	A 24-bit PC-relative offset to the symbol’s location.
  IMAGE_REL_PPC_REL14	    = $0007;  // 	A 14-bit PC-relative offset to the symbol’s location.
  IMAGE_REL_PPC_ADDR32NB	= $000A;  // 	The 32-bit RVA of the target.
  IMAGE_REL_PPC_SECREL	  = $000B;  // 	The 32-bit offset of the target from the beginning of its section. This is used to support debugging information and static thread local storage.
  IMAGE_REL_PPC_SECTION	  = $000C;  // 	The 16-bit section index of the section that contains the target. This is used to support debugging information.
  IMAGE_REL_PPC_SECREL16	= $000F;  // 	The 16-bit offset of the target from the beginning of its section. This is used to support debugging information and static thread local storage.
  IMAGE_REL_PPC_REFHI	    = $0010;  // 	The high 16 bits of the target’s 32-bit VA. This is used for the first instruction in a two-instruction sequence that loads a full address. This relocation must be immediately followed by a PAIR relocation whose SymbolTableIndex contains a signed 16-bit displacement that is added to the upper 16 bits that was taken from the location that is being relocated.
  IMAGE_REL_PPC_REFLO	    = $0011;  // 	The low 16 bits of the target’s VA.
  IMAGE_REL_PPC_PAIR	    = $0012;  // 	A relocation that is valid only when it immediately follows a REFHI or SECRELHI relocation. Its SymbolTableIndex contains a displacement and not an index into the symbol table.
  IMAGE_REL_PPC_SECRELLO	= $0013;  // 	The low 16 bits of the 32-bit offset of the target from the beginning of its section.
  IMAGE_REL_PPC_GPREL	    = $0015;  // 	The 16-bit signed displacement of the target relative to the GP register.
  IMAGE_REL_PPC_TOKEN	    = $0016;  // 	The CLR token.

  // Intel 386 Processors
  // The following relocation type indicators are defined for Intel 386 and compatible processors.
  IMAGE_REL_I386_ABSOLUTE	= $0000;  // 	The relocation is ignored.
  IMAGE_REL_I386_DIR16	  = $0001;  // 	Not supported.
  IMAGE_REL_I386_REL16	  = $0002;  // 	Not supported.
  IMAGE_REL_I386_DIR32	  = $0006;  // 	The target’s 32-bit VA.
  IMAGE_REL_I386_DIR32NB	= $0007;  // 	The target’s 32-bit RVA.
  IMAGE_REL_I386_SEG12	  = $0009;  // 	Not supported.
  IMAGE_REL_I386_SECTION	= $000A;  // 	The 16-bit section index of the section that contains the target. This is used to support debugging information.
  IMAGE_REL_I386_SECREL	  = $000B;  // 	The 32-bit offset of the target from the beginning of its section. This is used to support debugging information and static thread local storage.
  IMAGE_REL_I386_TOKEN	  = $000C;  // 	The CLR token.
  IMAGE_REL_I386_SECREL7	= $000D;  // 	A 7-bit offset from the base of the section that contains the target.
  IMAGE_REL_I386_REL32	  = $0014;  // 	The 32-bit relative displacement of the target. This supports the x86 relative branch and call instructions.

  // Intel Itanium Processor Family (IPF)
  // The following relocation type indicators are defined for the Intel Itanium processor family and compatible processors.
  // Note that relocations on instructions use the bundle’s offset and slot number for the relocation offset.
  IMAGE_REL_IA64_ABSOLUTE	  = $0000;  // 	The relocation is ignored.
  IMAGE_REL_IA64_IMM14	    = $0001;  // 	The instruction relocation can be followed by an ADDEND relocation whose value is added to the target address before it is inserted into the specified slot in the IMM14 bundle. The relocation target must be absolute or the image must be fixed.
  IMAGE_REL_IA64_IMM22	    = $0002;  // 	The instruction relocation can be followed by an ADDEND relocation whose value is added to the target address before it is inserted into the specified slot in the IMM22 bundle. The relocation target must be absolute or the image must be fixed.
  IMAGE_REL_IA64_IMM64	    = $0003;  // 	The slot number of this relocation must be one (1). The relocation can be followed by an ADDEND relocation whose value is added to the target address before it is stored in all three slots of the IMM64 bundle.
  IMAGE_REL_IA64_DIR32	    = $0004;  // 	The target’s 32-bit VA. This is supported only for /LARGEADDRESSAWARE:NO images.
  IMAGE_REL_IA64_DIR64	    = $0005;  // 	The target’s 64-bit VA.
  IMAGE_REL_IA64_PCREL21B	  = $0006;  // 	The instruction is fixed up with the 25-bit relative displacement of the 16-bit aligned target. The low 4 bits of the displacement are zero and are not stored.
  IMAGE_REL_IA64_PCREL21M	  = $0007;  // 	The instruction is fixed up with the 25-bit relative displacement of the 16-bit aligned target. The low 4 bits of the displacement, which are zero, are not stored.
  IMAGE_REL_IA64_PCREL21F	  = $0008;  // 	The LSBs of this relocation’s offset must contain the slot number whereas the rest is the bundle address. The bundle is fixed up with the 25-bit relative displacement of the 16-bit aligned target. The low 4 bits of the displacement are zero and are not stored.
  IMAGE_REL_IA64_GPREL22	  = $0009;  // 	The instruction relocation can be followed by an ADDEND relocation whose value is added to the target address and then a 22-bit GP-relative offset that is calculated and applied to the GPREL22 bundle.
  IMAGE_REL_IA64_LTOFF22	  = $000A;  // 	The instruction is fixed up with the 22-bit GP-relative offset to the target symbol’s literal table entry. The linker creates this literal table entry based on this relocation and the ADDEND relocation that might follow.
  IMAGE_REL_IA64_SECTION	  = $000B;  // 	The 16-bit section index of the section contains the target. This is used to support debugging information.
  IMAGE_REL_IA64_SECREL22	  = $000C;  // 	The instruction is fixed up with the 22-bit offset of the target from the beginning of its section. This relocation can be followed immediately by an ADDEND relocation, whose Value field contains the 32-bit unsigned offset of the target from the beginning of the section.
  IMAGE_REL_IA64_SECREL64I	= $000D;  // 	The slot number for this relocation must be one (1). The instruction is fixed up with the 64-bit offset of the target from the beginning of its section. This relocation can be followed immediately by an ADDEND relocation whose Value field contains the 32-bit unsigned offset of the target from the beginning of the section.
  IMAGE_REL_IA64_SECREL32	  = $000E;  // 	The address of data to be fixed up with the 32-bit offset of the target from the beginning of its section.
  IMAGE_REL_IA64_DIR32NB	  = $0010;  // 	The target’s 32-bit RVA.
  IMAGE_REL_IA64_SREL14	    = $0011;  // 	This is applied to a signed 14-bit immediate that contains the difference between two relocatable targets. This is a declarative field for the linker that indicates that the compiler has already emitted this value.
  IMAGE_REL_IA64_SREL22	    = $0012;  // 	This is applied to a signed 22-bit immediate that contains the difference between two relocatable targets. This is a declarative field for the linker that indicates that the compiler has already emitted this value.
  IMAGE_REL_IA64_SREL32	    = $0013;  // 	This is applied to a signed 32-bit immediate that contains the difference between two relocatable values. This is a declarative field for the linker that indicates that the compiler has already emitted this value.
  IMAGE_REL_IA64_UREL32	    = $0014;  // 	This is applied to an unsigned 32-bit immediate that contains the difference between two relocatable values. This is a declarative field for the linker that indicates that the compiler has already emitted this value.
  IMAGE_REL_IA64_PCREL60x	  = $0015;  // 	A 60-bit PC-relative fixup that always stays as a BRL instruction of an MLX bundle.
  IMAGE_REL_IA64_PCREL60B	  = $0016;  // 	A 60-bit PC-relative fixup. If the target displacement fits in a signed 25-bit field, convert the entire bundle to an MBB bundle with NOP.B in slot 1 and a 25-bit BR instruction (with the 4 lowest bits all zero and dropped) in slot 2.
  IMAGE_REL_IA64_PCREL60F	  = $0017;  // 	A 60-bit PC-relative fixup. If the target displacement fits in a signed 25-bit field, convert the entire bundle to an MFB bundle with NOP.F in slot 1 and a 25-bit (4 lowest bits all zero and dropped) BR instruction in slot 2.
  IMAGE_REL_IA64_PCREL60I	  = $0018;  // 	A 60-bit PC-relative fixup. If the target displacement fits in a signed 25-bit field, convert the entire bundle to an MIB bundle with NOP.I in slot 1 and a 25-bit (4 lowest bits all zero and dropped) BR instruction in slot 2.
  IMAGE_REL_IA64_PCREL60M	  = $0019;  // 	A 60-bit PC-relative fixup. If the target displacement fits in a signed 25-bit field, convert the entire bundle to an MMB bundle with NOP.M in slot 1 and a 25-bit (4 lowest bits all zero and dropped) BR instruction in slot 2.
  IMAGE_REL_IA64_IMMGPREL64	= $001a;  // 	A 64-bit GP-relative fixup.
  IMAGE_REL_IA64_TOKEN	    = $001b;  // 	A CLR token.
  IMAGE_REL_IA64_GPREL32  	= $001c;  // 	A 32-bit GP-relative fixup.
  IMAGE_REL_IA64_ADDEND	    = $001F;  // 	The relocation is valid only when it immediately follows one of the following relocations: IMM14, IMM22, IMM64, GPREL22, LTOFF22, LTOFF64, SECREL22, SECREL64I, or SECREL32. Its value contains the addend to apply to instructions within a bundle, not for data.

  // MIPS Processors
  // The following relocation type indicators are defined for MIPS processors.
  IMAGE_REL_MIPS_ABSOLUTE	  = $0000;  // 	The relocation is ignored.
  IMAGE_REL_MIPS_REFHALF	  = $0001;  // 	The high 16 bits of the target’s 32-bit VA.
  IMAGE_REL_MIPS_REFWORD	  = $0002;  // 	The target’s 32-bit VA.
  IMAGE_REL_MIPS_JMPADDR	  = $0003;  // 	The low 26 bits of the target’s VA. This supports the MIPS J and JAL instructions.
  IMAGE_REL_MIPS_REFHI	    = $0004;  // 	The high 16 bits of the target’s 32-bit VA. This is used for the first instruction in a two-instruction sequence that loads a full address. This relocation must be immediately followed by a PAIR relocation whose SymbolTableIndex contains a signed 16-bit displacement that is added to the upper 16 bits that are taken from the location that is being relocated.
  IMAGE_REL_MIPS_REFLO	    = $0005;  // 	The low 16 bits of the target’s VA.
  IMAGE_REL_MIPS_GPREL	    = $0006;  // 	A 16-bit signed displacement of the target relative to the GP register.
  IMAGE_REL_MIPS_LITERAL	  = $0007;  // 	The same as IMAGE_REL_MIPS_GPREL.
  IMAGE_REL_MIPS_SECTION	  = $000A;  // 	The 16-bit section index of the section contains the target. This is used to support debugging information.
  IMAGE_REL_MIPS_SECREL	    = $000B;  // 	The 32-bit offset of the target from the beginning of its section. This is used to support debugging information and static thread local storage.
  IMAGE_REL_MIPS_SECRELLO	  = $000C;  // 	The low 16 bits of the 32-bit offset of the target from the beginning of its section.
  IMAGE_REL_MIPS_SECRELHI	  = $000D;  // 	The high 16 bits of the 32-bit offset of the target from the beginning of its section. An IMAGE_REL_MIPS_PAIR relocation must immediately follow this one. The SymbolTableIndex of the PAIR relocation contains a signed 16-bit displacement that is added to the upper 16 bits that are taken from the location that is being relocated.
  IMAGE_REL_MIPS_JMPADDR16	= $0010;  // 	The low 26 bits of the target’s VA. This supports the MIPS16 JAL instruction.
  IMAGE_REL_MIPS_REFWORDNB	= $0022;  // 	The target’s 32-bit RVA.
  IMAGE_REL_MIPS_PAIR	      = $0025;  // 	The relocation is valid only when it immediately follows a REFHI or SECRELHI relocation. Its SymbolTableIndex contains a displacement and not an index into the symbol table.

  // Mitsubishi M32R
  // The following relocation type indicators are defined for the Mitsubishi M32R processors.
  IMAGE_REL_M32R_ABSOLUTE	= $0000;  // 	The relocation is ignored.
  IMAGE_REL_M32R_ADDR32	  = $0001;  // 	The target’s 32-bit VA.
  IMAGE_REL_M32R_ADDR32NB	= $0002;  // 	The target’s 32-bit RVA.
  IMAGE_REL_M32R_ADDR24	  = $0003;  // 	The target’s 24-bit VA.
  IMAGE_REL_M32R_GPREL16	= $0004;  // 	The target’s 16-bit offset from the GP register.
  IMAGE_REL_M32R_PCREL24	= $0005;  // 	The target’s 24-bit offset from the program counter (PC), shifted left by 2 bits and sign-extended
  IMAGE_REL_M32R_PCREL16	= $0006;  // 	The target’s 16-bit offset from the PC, shifted left by 2 bits and sign-extended
  IMAGE_REL_M32R_PCREL8 	= $0007;  // 	The target’s 8-bit offset from the PC, shifted left by 2 bits and sign-extended
  IMAGE_REL_M32R_REFHALF	= $0008;  // 	The 16 MSBs of the target VA.
  IMAGE_REL_M32R_REFHI	  = $0009;  // 	The 16 MSBs of the target VA, adjusted for LSB sign extension. This is used for the first instruction in a two-instruction sequence that loads a full 32-bit address. This relocation must be immediately followed by a PAIR relocation whose SymbolTableIndex contains a signed 16-bit displacement that is added to the upper 16 bits that are taken from the location that is being relocated.
  IMAGE_REL_M32R_REFLO	  = $000A;  // 	The 16 LSBs of the target VA.
  IMAGE_REL_M32R_PAIR	    = $000B;  // 	The relocation must follow the REFHI relocation. Its SymbolTableIndex contains a displacement and not an index into the symbol table.
  IMAGE_REL_M32R_SECTION	= $000C;  // 	The 16-bit section index of the section that contains the target. This is used to support debugging information.
  IMAGE_REL_M32R_SECREL	  = $000D;  // 	The 32-bit offset of the target from the beginning of its section. This is used to support debugging information and static thread local storage.
  IMAGE_REL_M32R_TOKEN	  = $000E;  // 	The CLR token.


// 5.6.2. Base Relocation Types
  IMAGE_REL_BASED_ABSOLUTE	      = 0;  //  The base relocation is skipped. This type can be used to pad a block.
  IMAGE_REL_BASED_HIGH	          = 1;  //	The base relocation adds the high 16 bits of the difference to the 16-bit field at offset. The 16-bit field represents the high value of a 32-bit word.
  IMAGE_REL_BASED_LOW	            = 2;  //	The base relocation adds the low 16 bits of the difference to the 16-bit field at offset. The 16-bit field represents the low half of a 32-bit word.
  IMAGE_REL_BASED_HIGHLOW	        = 3;  //	The base relocation applies all 32 bits of the difference to the 32-bit field at offset.
  IMAGE_REL_BASED_HIGHADJ	        = 4;  //	The base relocation adds the high 16 bits of the difference to the 16-bit field at offset. The 16-bit field represents the high value of a 32-bit word. The low 16 bits of the 32-bit value are stored in the 16-bit word that follows this base relocation. This means that this base relocation occupies two slots.
  IMAGE_REL_BASED_MIPS_JMPADDR    = 5;  //  For MIPS machine types, the base relocation applies to a MIPS jump instruction.
  IMAGE_REL_BASED_ARM_MOV32A	    = 5;  //  For ARM machine types, the base relocation applies the difference to the 32-bit value encoded in the immediate fields of a contiguous MOVW+MOVT pair in ARM mode at offset.
                                //  6;  //	Reserved, must be zero.
  IMAGE_REL_BASED_ARM_MOV32T      =	7;  //	The base relocation applies the difference to the 32-bit value encoded in the immediate fields of a contiguous MOVW+MOVT pair in Thumb mode at offset.
  IMAGE_REL_BASED_MIPS_JMPADDR16  =	9;  //	The base relocation applies to a MIPS16 jump instruction.
  IMAGE_REL_BASED_DIR64	          = 10; //	The base relocation applies the difference to the 64-bit field at offset.

