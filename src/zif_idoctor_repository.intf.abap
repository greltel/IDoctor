"! Reads IDoc types and IDocs and saves changed IDocs - the boundary between IDoctor and the
"! SAP IDoc interface. Consumers depend on this interface and double it in their tests.
INTERFACE zif_idoctor_repository
  PUBLIC.

  TYPES:
    "! How save( ) treats the logical unit of work
    BEGIN OF ty_save_settings,
      "! abap_true: commit right after the IDoc is written; abap_false (default): the caller
      "! ends the LUW with COMMIT WORK or ROLLBACK WORK
      commit TYPE abap_bool,
    END OF ty_save_settings.

  "! Reads the syntax of an IDoc type: its segment types with parent, order and cardinality,
  "! and where each field sits in the segment data - taken from the DDIC structure of the
  "! segment type, the same layout get_data( ) and set_data( ) of a segment use. Each IDoc type
  "! is read once per repository instance.
  "!
  "! @parameter idoc_type | Basic type, e.g. ORDERS05
  "! @parameter extension | Extension of the basic type; initial for none
  "! @parameter result    | Syntax for the creation methods create( ) and from_edidd( ) of zcl_idoctor
  "! @raising zcx_idoctor_error | The basic type or the extension does not exist, or the extension
  "!                             does not belong to the basic type
  METHODS read_syntax
    IMPORTING idoc_type     TYPE edidc-idoctp
              extension     TYPE edidc-cimtyp OPTIONAL
    RETURNING VALUE(result) TYPE zcl_idoctor=>ty_syntax
    RAISING   zcx_idoctor_error.

  "! Loads an IDoc from the database, together with the syntax of its type.
  "!
  "! @parameter docnum | IDoc number
  "! @parameter result | The IDoc as a tree
  "! @raising zcx_idoctor_error | The IDoc does not exist, or its records do not fit its IDoc type
  METHODS load
    IMPORTING docnum        TYPE edidc-docnum
    RETURNING VALUE(result) TYPE REF TO zcl_idoctor
    RAISING   zcx_idoctor_error.

  "! Writes the changed segment contents of a loaded IDoc to the database through the IDoc
  "! edit interface of SAP, which marks the IDoc as edited and keeps its original. Only
  "! contents are saved: the IDoc must still have the segments it has in the database, and it
  "! must not have been changed in the database since it was loaded. Commits only when
  "! settings-commit is set. After a save, load the IDoc again before changing it once more.
  "!
  "! @parameter idoc     | IDoc loaded with load( ) and changed in memory
  "! @parameter settings | How the LUW is treated
  "! @raising zcx_idoctor_error | The IDoc was not loaded from the database or was changed there
  "!                             since, has other segments than there, is locked or may not be
  "!                             changed in its status, or the database update failed
  METHODS save
    IMPORTING idoc     TYPE REF TO zcl_idoctor
              settings TYPE ty_save_settings OPTIONAL
    RAISING   zcx_idoctor_error.

ENDINTERFACE.
