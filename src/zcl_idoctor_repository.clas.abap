"! Reads IDoc types and IDocs and saves changed IDocs through the SAP IDoc interface - the only
"! place of IDoctor that calls function modules. The LUW stays with the caller: save( ) commits
"! only when it is asked to.
CLASS zcl_idoctor_repository DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_idoctor_repository.

  PRIVATE SECTION.
    TYPES ty_segment_rows TYPE STANDARD TABLE OF edi_iapi11 WITH EMPTY KEY.
    TYPES ty_status_records TYPE STANDARD TABLE OF edi_ds40 WITH EMPTY KEY.
    TYPES ty_syntaxes TYPE HASHED TABLE OF zcl_idoctor=>ty_syntax WITH UNIQUE KEY idoc_type extension.
    TYPES:
      BEGIN OF ty_cardinality,
        min TYPE int8,
        max TYPE int8,
      END OF ty_cardinality.
    TYPES:
      BEGIN OF ty_idoc_content,
        control TYPE edidc,
        data    TYPE zcl_idoctor=>ty_data_records,
      END OF ty_idoc_content.

    " return codes of the classic exceptions, as numbered in the EXCEPTIONS clause of each call
    CONSTANTS:
      BEGIN OF type_read_failure,
        object_unknown     TYPE sysubrc VALUE 1,
        segment_unknown    TYPE sysubrc VALUE 2,
        relation_not_found TYPE sysubrc VALUE 3,
      END OF type_read_failure.
    CONSTANTS:
      BEGIN OF idoc_read_failure,
        not_existing   TYPE sysubrc VALUE 1,
        invalid_number TYPE sysubrc VALUE 2,
      END OF idoc_read_failure.
    CONSTANTS:
      BEGIN OF open_failure,
        foreign_lock   TYPE sysubrc VALUE 1,
        not_existing   TYPE sysubrc VALUE 2,
        not_changeable TYPE sysubrc VALUE 4,
      END OF open_failure.
    CONSTANTS:
      BEGIN OF change_failure,
        not_open          TYPE sysubrc VALUE 1,
        record_not_stored TYPE sysubrc VALUE 2,
      END OF change_failure.
    CONSTANTS:
      BEGIN OF close_failure,
        not_open TYPE sysubrc VALUE 1,
        db_error TYPE sysubrc VALUE 2,
      END OF close_failure.

    " syntaxes read so far, by IDoc type and extension
    DATA syntaxes TYPE ty_syntaxes.

    METHODS read_type
      IMPORTING idoc_type     TYPE edidc-idoctp
                extension     TYPE edidc-cimtyp
      RETURNING VALUE(result) TYPE zcl_idoctor=>ty_syntax
      RAISING   zcx_idoctor_error.

    METHODS segment_definitions
      IMPORTING rows          TYPE ty_segment_rows
      RETURNING VALUE(result) TYPE zcl_idoctor=>ty_segment_definitions.

    METHODS cardinality_of
      IMPORTING row           TYPE edi_iapi11
      RETURNING VALUE(result) TYPE ty_cardinality.

    METHODS field_definitions
      IMPORTING segments      TYPE zcl_idoctor=>ty_segment_definitions
      RETURNING VALUE(result) TYPE zcl_idoctor=>ty_field_definitions.

    METHODS fields_of
      IMPORTING segment_type  TYPE zcl_idoctor=>ty_segment_type
      RETURNING VALUE(result) TYPE zcl_idoctor=>ty_field_definitions.

    METHODS read_idoc
      IMPORTING docnum        TYPE edidc-docnum
      RETURNING VALUE(result) TYPE ty_idoc_content
      RAISING   zcx_idoctor_error.

    METHODS write_changes
      IMPORTING idoc     TYPE REF TO zcl_idoctor
                stored   TYPE ty_idoc_content
                settings TYPE zif_idoctor_repository=>ty_save_settings
      RAISING   zcx_idoctor_error.

    METHODS check_unchanged
      IMPORTING loaded TYPE edidc
                stored TYPE edidc
      RAISING   zcx_idoctor_error.

    METHODS has_same_segments
      IMPORTING stored        TYPE zcl_idoctor=>ty_data_records
                current       TYPE zcl_idoctor=>ty_data_records
      RETURNING VALUE(result) TYPE abap_bool.

    METHODS changed_records
      IMPORTING stored        TYPE zcl_idoctor=>ty_data_records
                current       TYPE zcl_idoctor=>ty_data_records
      RETURNING VALUE(result) TYPE zcl_idoctor=>ty_data_records.

    METHODS open_for_edit
      IMPORTING docnum        TYPE edidc-docnum
      RETURNING VALUE(result) TYPE ty_idoc_content
      RAISING   zcx_idoctor_error.

    METHODS change_records
      IMPORTING docnum  TYPE edidc-docnum
                records TYPE zcl_idoctor=>ty_data_records
      RAISING   zcx_idoctor_error.

    METHODS close_edit
      IMPORTING docnum TYPE edidc-docnum
                update TYPE abap_bool
                commit TYPE abap_bool
      RAISING   zcx_idoctor_error.

    METHODS discard_edit
      IMPORTING docnum TYPE edidc-docnum.

    METHODS raise_type_error
      IMPORTING failure   TYPE sysubrc
                idoc_type TYPE edidc-idoctp
                extension TYPE edidc-cimtyp
      RAISING   zcx_idoctor_error.

    METHODS raise_read_error
      IMPORTING failure TYPE sysubrc
                docnum  TYPE edidc-docnum
      RAISING   zcx_idoctor_error.

    METHODS raise_open_error
      IMPORTING failure TYPE sysubrc
                docnum  TYPE edidc-docnum
      RAISING   zcx_idoctor_error.

    METHODS raise_change_error
      IMPORTING failure TYPE sysubrc
                docnum  TYPE edidc-docnum
      RAISING   zcx_idoctor_error.

    METHODS raise_close_error
      IMPORTING failure TYPE sysubrc
                docnum  TYPE edidc-docnum
      RAISING   zcx_idoctor_error.
ENDCLASS.


CLASS zcl_idoctor_repository IMPLEMENTATION.

  METHOD zif_idoctor_repository~read_syntax.
    DATA(type_name) = CONV edidc-idoctp( to_upper( idoc_type ) ).
    DATA(extension_name) = CONV edidc-cimtyp( to_upper( extension ) ).
    IF line_exists( syntaxes[ idoc_type = type_name
                              extension = extension_name ] ).
      result = syntaxes[ idoc_type = type_name
                         extension = extension_name ].
      RETURN.
    ENDIF.
    result = read_type( idoc_type = type_name
                        extension = extension_name ).
    INSERT result INTO TABLE syntaxes.
  ENDMETHOD.


  METHOD zif_idoctor_repository~load.
    DATA(content) = read_idoc( docnum ).
    result = zcl_idoctor=>from_edidd(
               syntax  = zif_idoctor_repository~read_syntax( idoc_type = content-control-idoctp
                                                             extension = content-control-cimtyp )
               data    = content-data
               control = content-control ).
  ENDMETHOD.


  METHOD zif_idoctor_repository~save.
    DATA(docnum) = idoc->control( )-docnum.
    IF docnum IS INITIAL.
      RAISE EXCEPTION TYPE zcx_idoctor_error MESSAGE e039(zidoctor).
    ENDIF.
    DATA(stored) = open_for_edit( docnum ).
    TRY.
        write_changes( idoc     = idoc
                       stored   = stored
                       settings = settings ).
      CLEANUP.
        discard_edit( docnum ).
    ENDTRY.
  ENDMETHOD.


  METHOD read_type.
    DATA segment_rows TYPE ty_segment_rows.
    DATA field_rows TYPE STANDARD TABLE OF edi_iapi12 WITH EMPTY KEY.

    " PT_FIELDS is passed in case the interface requires it; the field layout is taken from the
    " DDIC structure of each segment type (fields_of), the layout SDATA really has
    CALL FUNCTION 'IDOCTYPE_READ_COMPLETE'
      EXPORTING
        pi_idoctyp         = idoc_type
        pi_cimtyp          = extension
      TABLES
        pt_segments        = segment_rows
        pt_fields          = field_rows
      EXCEPTIONS
        object_unknown     = 1
        segment_unknown    = 2
        relation_not_found = 3
        OTHERS             = 4.
    IF sy-subrc <> 0.
      raise_type_error( failure   = sy-subrc
                        idoc_type = idoc_type
                        extension = extension ).
    ENDIF.
    result = VALUE #( idoc_type = idoc_type
                      extension = extension
                      segments  = segment_definitions( segment_rows ) ).
    result-fields = field_definitions( result-segments ).
  ENDMETHOD.


  METHOD segment_definitions.
    LOOP AT rows INTO DATA(row).
      " the order in which the IDoc type lists its segments is the order siblings must follow
      DATA(position) = sy-tabix.
      DATA(cardinality) = cardinality_of( row ).
      INSERT VALUE #( segment_type    = row-segmenttyp
                      definition      = row-segmentdef
                      parent_type     = row-parseg
                      position        = position
                      hierarchy_level = row-hlevel
                      min_occurrence  = cardinality-min
                      max_occurrence  = cardinality-max ) INTO TABLE result.
    ENDLOOP.
  ENDMETHOD.


  METHOD cardinality_of.
    " the first segment of a segment group carries the cardinality of the whole group in GRP_*;
    " its own MUSTFL / OCCMIN / OCCMAX describe it within one group instance
    DATA(is_group) = xsdbool( row-parflg = abap_true AND row-grp_occmax IS NOT INITIAL ).
    DATA(is_mandatory) = COND abap_bool( WHEN is_group = abap_true THEN row-grp_mustfl ELSE row-mustfl ).
    DATA(minimum) = COND int8( WHEN is_group = abap_true THEN row-grp_occmin ELSE row-occmin ).
    result-max = COND #( WHEN is_group = abap_true THEN row-grp_occmax ELSE row-occmax ).
    " SAP keeps OCCMIN at 1 for optional segments as well - the mandatory flag decides
    result-min = COND #( WHEN is_mandatory = abap_false THEN 0
                         WHEN minimum < 1 THEN 1
                         ELSE minimum ).
  ENDMETHOD.


  METHOD field_definitions.
    LOOP AT segments INTO DATA(segment).
      INSERT LINES OF fields_of( segment-segment_type ) INTO TABLE result.
    ENDLOOP.
  ENDMETHOD.


  METHOD fields_of.
    DATA descriptor TYPE REF TO cl_abap_typedescr.

    " SDATA is the character-like DDIC structure of the segment type moved into one field, so the
    " layout of that structure is exactly the layout of SDATA - also what get_data( ) relies on
    cl_abap_typedescr=>describe_by_name(
      EXPORTING
        p_name         = segment_type
      RECEIVING
        p_descr_ref    = descriptor
      EXCEPTIONS
        type_not_found = 1
        OTHERS         = 2 ).
    IF sy-subrc <> 0 OR descriptor->kind <> cl_abap_typedescr=>kind_struct.
      RETURN.
    ENDIF.
    DATA(structure) = CAST cl_abap_structdescr( descriptor ).
    DATA(offset) = 0.
    LOOP AT structure->components INTO DATA(component).
      DATA(length) = component-length / cl_abap_char_utilities=>charsize.
      INSERT VALUE #( segment_type = segment_type
                      field_name   = component-name
                      offset       = offset
                      length       = length ) INTO TABLE result.
      offset = offset + length.
    ENDLOOP.
  ENDMETHOD.


  METHOD read_idoc.
    DATA status_records TYPE STANDARD TABLE OF edids WITH EMPTY KEY.

    CALL FUNCTION 'IDOC_READ_COMPLETELY'
      EXPORTING
        document_number         = docnum
      IMPORTING
        idoc_control            = result-control
      TABLES
        int_edids               = status_records
        int_edidd               = result-data
      EXCEPTIONS
        document_not_exist      = 1
        document_number_invalid = 2
        OTHERS                  = 3.
    IF sy-subrc <> 0.
      raise_read_error( failure = sy-subrc
                        docnum  = docnum ).
    ENDIF.
  ENDMETHOD.


  METHOD write_changes.
    check_unchanged( loaded = idoc->control( )
                     stored = stored-control ).
    DATA(current) = idoc->to_edidd( ).
    IF has_same_segments( stored  = stored-data
                          current = current ) = abap_false.
      RAISE EXCEPTION TYPE zcx_idoctor_error MESSAGE e038(zidoctor) WITH stored-control-docnum.
    ENDIF.
    DATA(changes) = changed_records( stored  = stored-data
                                     current = current ).
    IF changes IS NOT INITIAL.
      change_records( docnum  = stored-control-docnum
                      records = changes ).
    ENDIF.
    close_edit( docnum = stored-control-docnum
                update = xsdbool( changes IS NOT INITIAL )
                commit = settings-commit ).
  ENDMETHOD.


  METHOD check_unchanged.
    " the time of the last change tells whether anybody touched the IDoc since it was loaded -
    " saving over such a change would undo it
    IF stored-upddat <> loaded-upddat OR stored-updtim <> loaded-updtim.
      RAISE EXCEPTION TYPE zcx_idoctor_error MESSAGE e050(zidoctor) WITH stored-docnum.
    ENDIF.
  ENDMETHOD.


  METHOD has_same_segments.
    IF lines( stored ) <> lines( current ).
      RETURN.
    ENDIF.
    LOOP AT stored INTO DATA(stored_record).
      IF current[ sy-tabix ]-segnam <> stored_record-segnam.
        RETURN.
      ENDIF.
    ENDLOOP.
    result = abap_true.
  ENDMETHOD.


  METHOD changed_records.
    " the stored record keeps its numbers and links - only the segment data is taken over
    LOOP AT stored INTO DATA(stored_record).
      DATA(current_data) = current[ sy-tabix ]-sdata.
      IF current_data <> stored_record-sdata.
        stored_record-sdata = current_data.
        INSERT stored_record INTO TABLE result.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD open_for_edit.
    CALL FUNCTION 'EDI_DOCUMENT_OPEN_FOR_EDIT'
      EXPORTING
        document_number               = docnum
      IMPORTING
        idoc_control                  = result-control
      TABLES
        idoc_data                     = result-data
      EXCEPTIONS
        document_foreign_lock         = 1
        document_not_exist            = 2
        document_not_open             = 3
        status_is_unable_for_changing = 4
        OTHERS                        = 5.
    IF sy-subrc <> 0.
      raise_open_error( failure = sy-subrc
                        docnum  = docnum ).
    ENDIF.
  ENDMETHOD.


  METHOD change_records.
    DATA(changed) = records.

    CALL FUNCTION 'EDI_CHANGE_DATA_SEGMENTS'
      TABLES
        idoc_changed_data_range = changed
      EXCEPTIONS
        idoc_not_open           = 1
        data_record_not_exist   = 2
        OTHERS                  = 3.
    IF sy-subrc <> 0.
      raise_change_error( failure = sy-subrc
                          docnum  = docnum ).
    ENDIF.
  ENDMETHOD.


  METHOD close_edit.
    DATA status_records TYPE ty_status_records.

    CALL FUNCTION 'EDI_DOCUMENT_CLOSE_EDIT'
      EXPORTING
        document_number = docnum
        do_commit       = commit
        do_update       = update
      TABLES
        status_records  = status_records
      EXCEPTIONS
        idoc_not_open   = 1
        db_error        = 2
        OTHERS          = 3.
    IF sy-subrc <> 0.
      raise_close_error( failure = sy-subrc
                         docnum  = docnum ).
    ENDIF.
  ENDMETHOD.


  METHOD discard_edit.
    DATA status_records TYPE ty_status_records.

    " runs while an exception leaves save( ): closing without update releases the IDoc, and a
    " failure here must not replace that exception, so the outcome is deliberately not evaluated
    CALL FUNCTION 'EDI_DOCUMENT_CLOSE_EDIT'
      EXPORTING
        document_number = docnum
        do_commit       = abap_false
        do_update       = abap_false
      TABLES
        status_records  = status_records
      EXCEPTIONS
        OTHERS          = 1.
  ENDMETHOD.


  METHOD raise_type_error.
    DATA(failure_text) = |{ failure }|.
    CASE failure.
      WHEN type_read_failure-object_unknown.
        RAISE EXCEPTION TYPE zcx_idoctor_error MESSAGE e032(zidoctor) WITH idoc_type extension.
      WHEN type_read_failure-segment_unknown.
        RAISE EXCEPTION TYPE zcx_idoctor_error MESSAGE e034(zidoctor) WITH idoc_type.
      WHEN type_read_failure-relation_not_found.
        RAISE EXCEPTION TYPE zcx_idoctor_error MESSAGE e033(zidoctor) WITH idoc_type extension.
      WHEN OTHERS.
        RAISE EXCEPTION TYPE zcx_idoctor_error MESSAGE e043(zidoctor) WITH idoc_type failure_text.
    ENDCASE.
  ENDMETHOD.


  METHOD raise_read_error.
    DATA(failure_text) = |{ failure }|.
    CASE failure.
      WHEN idoc_read_failure-not_existing.
        RAISE EXCEPTION TYPE zcx_idoctor_error MESSAGE e030(zidoctor) WITH docnum.
      WHEN idoc_read_failure-invalid_number.
        RAISE EXCEPTION TYPE zcx_idoctor_error MESSAGE e031(zidoctor) WITH docnum.
      WHEN OTHERS.
        RAISE EXCEPTION TYPE zcx_idoctor_error MESSAGE e042(zidoctor) WITH docnum failure_text.
    ENDCASE.
  ENDMETHOD.


  METHOD raise_open_error.
    DATA(failure_text) = |{ failure }|.
    CASE failure.
      WHEN open_failure-foreign_lock.
        RAISE EXCEPTION TYPE zcx_idoctor_error MESSAGE e035(zidoctor) WITH docnum.
      WHEN open_failure-not_existing.
        RAISE EXCEPTION TYPE zcx_idoctor_error MESSAGE e047(zidoctor) WITH docnum.
      WHEN open_failure-not_changeable.
        RAISE EXCEPTION TYPE zcx_idoctor_error MESSAGE e036(zidoctor) WITH docnum.
      WHEN OTHERS.
        RAISE EXCEPTION TYPE zcx_idoctor_error MESSAGE e044(zidoctor) WITH docnum failure_text.
    ENDCASE.
  ENDMETHOD.


  METHOD raise_change_error.
    DATA(failure_text) = |{ failure }|.
    CASE failure.
      WHEN change_failure-not_open.
        RAISE EXCEPTION TYPE zcx_idoctor_error MESSAGE e037(zidoctor) WITH docnum.
      WHEN change_failure-record_not_stored.
        RAISE EXCEPTION TYPE zcx_idoctor_error MESSAGE e049(zidoctor) WITH docnum.
      WHEN OTHERS.
        RAISE EXCEPTION TYPE zcx_idoctor_error MESSAGE e045(zidoctor) WITH docnum failure_text.
    ENDCASE.
  ENDMETHOD.


  METHOD raise_close_error.
    DATA(failure_text) = |{ failure }|.
    CASE failure.
      WHEN close_failure-not_open.
        RAISE EXCEPTION TYPE zcx_idoctor_error MESSAGE e048(zidoctor) WITH docnum.
      WHEN close_failure-db_error.
        RAISE EXCEPTION TYPE zcx_idoctor_error MESSAGE e041(zidoctor) WITH docnum.
      WHEN OTHERS.
        RAISE EXCEPTION TYPE zcx_idoctor_error MESSAGE e046(zidoctor) WITH docnum failure_text.
    ENDCASE.
  ENDMETHOD.

ENDCLASS.

