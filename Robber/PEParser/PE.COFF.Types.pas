unit PE.COFF.Types;

interface

type
  // 4.4.1. Symbol Name Representation

  TCOFFSymbolTableName = packed record
    case byte of
      0:
        (ShortName: array [0 .. 7] of AnsiChar);
      1:
        (u: record Zeroes, Offset: uint32; end);
  end;

  // 4.4. COFF Symbol Table

  TCOFFSymbolTable = packed record

    Name: TCOFFSymbolTableName;

    // The value that is associated with the symbol. The interpretation of this
    // field depends on SectionNumber and StorageClass. A typical meaning is
    // the relocatable address.
    Value: uint32;

    // The signed integer that identifies the section, using a one-based index
    // into the section table. Some values have special meaning, as defined in
    // section 5.4.2, “Section Number Values.”
    SectionNumber: int16;

    // A number that represents type. Microsoft tools set this field to 0x20
    // (function) or 0x0 (not a function). For more information, see section
    // 5.4.3, “Type Representation.”
    &Type: uint16;

    // An enumerated value that represents storage class. For more information,
    // see section 5.4.4, “Storage Class.”
    StorageClass: uint8;

    // The number of auxiliary symbol table entries that follow this record.
    NumberOfAuxSymbols: uint8;

  end;

  // 4.4.2. Section Number Values

const
  // The symbol record is not yet assigned a section. A value of zero indicates
  // that a reference to an external symbol is defined elsewhere. A value of
  // non-zero is a common symbol with a size that is specified by the value.
  IMAGE_SYM_UNDEFINED = 0;

  // The symbol has an absolute (non-relocatable) value and is not an address.
  IMAGE_SYM_ABSOLUTE = -1;

  // The symbol provides general type or debugging information but does not
  // correspond to a section. Microsoft tools use this setting along with .file
  // records (storage class FILE).
  IMAGE_SYM_DEBUG = -2;

  // ... also other info

implementation

end.
