" IDoctor demo 03 - fix IDocs in error status in bulk: in every selected IDoc, replace a wrong
" field value by the right one and save the IDoc. One IDoc is one LUW: each IDoc is committed on
" its own, and a failing IDoc is rolled back without touching the others. Reprocess the saved
" IDocs afterwards as usual (e.g. with BD87).
REPORT zidoctor_demo_03.

CONSTANTS status_application_error TYPE edidc-status VALUE '51'.

DATA idoc_control TYPE edidc.

SELECT-OPTIONS s_docnum FOR idoc_control-docnum.
SELECT-OPTIONS s_mestyp FOR idoc_control-mestyp.
SELECT-OPTIONS s_credat FOR idoc_control-credat.
PARAMETERS p_status TYPE edidc-status OBLIGATORY.
PARAMETERS p_segnam TYPE edidd-segnam OBLIGATORY.
PARAMETERS p_field TYPE fieldname OBLIGATORY.
PARAMETERS p_old TYPE c LENGTH 70 LOWER CASE OBLIGATORY.
PARAMETERS p_new TYPE c LENGTH 70 LOWER CASE.
PARAMETERS p_test AS CHECKBOX DEFAULT abap_true.

"! Finds the IDocs to fix - kept apart from the fixing so that the fix works on any list of IDocs
CLASS lcl_idoc_finder DEFINITION FINAL.
  PUBLIC SECTION.
    TYPES ty_docnum_range TYPE RANGE OF edidc-docnum.
    TYPES ty_mestyp_range TYPE RANGE OF edidc-mestyp.
    TYPES ty_credat_range TYPE RANGE OF edidc-credat.
    TYPES:
      BEGIN OF ty_selection,
        docnums       TYPE ty_docnum_range,
        message_types TYPE ty_mestyp_range,
        created_on    TYPE ty_credat_range,
        status        TYPE edidc-status,
      END OF ty_selection.
    TYPES ty_docnums TYPE STANDARD TABLE OF edidc-docnum WITH EMPTY KEY.

    METHODS find_idocs
      IMPORTING selection     TYPE ty_selection
      RETURNING VALUE(result) TYPE ty_docnums.
ENDCLASS.


CLASS lcl_idoc_finder IMPLEMENTATION.

  METHOD find_idocs.
    " EDIDC has no released CDS view; it is read directly, which is fine on-premise
    SELECT FROM edidc
      FIELDS docnum
      WHERE docnum IN @selection-docnums
        AND mestyp IN @selection-message_types
        AND credat IN @selection-created_on
        AND status  = @selection-status
      ORDER BY docnum
      INTO TABLE @result.
  ENDMETHOD.

ENDCLASS.


CLASS lcl_bulk_fix DEFINITION FINAL.
  PUBLIC SECTION.
    TYPES:
      BEGIN OF ty_fix,
        segment_type TYPE edidd-segnam,
        field        TYPE fieldname,
        old_value    TYPE string,
        new_value    TYPE string,
        is_test      TYPE abap_bool,
      END OF ty_fix.
    TYPES:
      BEGIN OF ty_result,
        docnum  TYPE edidc-docnum,
        changed TYPE i,
        message TYPE string,
      END OF ty_result.
    TYPES ty_results TYPE STANDARD TABLE OF ty_result WITH EMPTY KEY.

    METHODS constructor
      IMPORTING repository TYPE REF TO zif_idoctor_repository.

    METHODS run
      IMPORTING docnums       TYPE lcl_idoc_finder=>ty_docnums
                fix           TYPE ty_fix
      RETURNING VALUE(result) TYPE ty_results.

  PRIVATE SECTION.
    DATA repository TYPE REF TO zif_idoctor_repository.

    METHODS fix_one
      IMPORTING docnum        TYPE edidc-docnum
                fix           TYPE ty_fix
      RETURNING VALUE(result) TYPE ty_result.

    METHODS apply
      IMPORTING docnum        TYPE edidc-docnum
                fix           TYPE ty_fix
      RETURNING VALUE(result) TYPE i
      RAISING   zcx_idoctor_error.
ENDCLASS.


CLASS lcl_bulk_fix IMPLEMENTATION.

  METHOD constructor.
    me->repository = repository.
  ENDMETHOD.


  METHOD run.
    LOOP AT docnums INTO DATA(docnum).
      INSERT fix_one( docnum = docnum
                      fix    = fix ) INTO TABLE result.
    ENDLOOP.
  ENDMETHOD.


  METHOD fix_one.
    result-docnum = docnum.
    TRY.
        result-changed = apply( docnum = docnum
                                fix    = fix ).
        DATA(changed_text) = |{ result-changed }|.
        IF result-changed = 0.
          MESSAGE s063(zidoctor) WITH fix-segment_type fix-field fix-old_value INTO result-message.
        ELSEIF fix-is_test = abap_true.
          MESSAGE s062(zidoctor) WITH changed_text INTO result-message.
        ELSE.
          MESSAGE s061(zidoctor) WITH changed_text INTO result-message.
        ENDIF.
      CATCH zcx_idoctor_error INTO DATA(error).
        " one IDoc is one LUW - whatever this IDoc left behind is undone, the others stay
        ROLLBACK WORK.
        result-message = error->get_text( ).
    ENDTRY.
  ENDMETHOD.


  METHOD apply.
    DATA(idoc) = repository->load( docnum ).
    DATA(segments) = idoc->find_all( name  = fix-segment_type
                                     field = fix-field
                                     value = fix-old_value ).
    LOOP AT segments INTO DATA(segment).
      segment->set_value( field = fix-field
                          value = fix-new_value ).
    ENDLOOP.
    result = lines( segments ).
    IF result > 0 AND fix-is_test = abap_false.
      repository->save( idoc     = idoc
                        settings = VALUE #( commit = abap_true ) ).
    ENDIF.
  ENDMETHOD.

ENDCLASS.


"! Shows the result of the bulk fix, one line per IDoc
CLASS lcl_result_list DEFINITION FINAL.
  PUBLIC SECTION.
    "! @parameter results | Result per IDoc
    METHODS show
      IMPORTING results TYPE lcl_bulk_fix=>ty_results.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF column,
        changed TYPE lvc_fname VALUE 'CHANGED',
        message TYPE lvc_fname VALUE 'MESSAGE',
      END OF column.

    METHODS set_title
      IMPORTING columns TYPE REF TO cl_salv_columns_table
                name    TYPE lvc_fname
                title   TYPE csequence
      RAISING   cx_salv_not_found.
ENDCLASS.


CLASS lcl_result_list IMPLEMENTATION.

  METHOD show.
    DATA(rows) = results.
    TRY.
        cl_salv_table=>factory( IMPORTING r_salv_table = DATA(alv)
                                CHANGING  t_table      = rows ).
        DATA(columns) = alv->get_columns( ).
        columns->set_optimize( ).
        set_title( columns = columns
                   name    = column-changed
                   title   = TEXT-001 ).
        set_title( columns = columns
                   name    = column-message
                   title   = TEXT-002 ).
        alv->display( ).
      CATCH cx_salv_msg cx_salv_not_found INTO DATA(error).
        MESSAGE error TYPE 'S' DISPLAY LIKE 'E'.
    ENDTRY.
  ENDMETHOD.


  METHOD set_title.
    " a column typed without a DDIC data element has no heading of its own
    DATA(salv_column) = columns->get_column( name ).
    salv_column->set_short_text( CONV #( title ) ).
    salv_column->set_medium_text( CONV #( title ) ).
    salv_column->set_long_text( CONV #( title ) ).
  ENDMETHOD.

ENDCLASS.


INITIALIZATION.
  p_status = status_application_error.

START-OF-SELECTION.
  DATA(selection) = VALUE lcl_idoc_finder=>ty_selection( docnums       = s_docnum[]
                                                         message_types = s_mestyp[]
                                                         created_on    = s_credat[]
                                                         status        = p_status ).
  DATA(fix) = VALUE lcl_bulk_fix=>ty_fix( segment_type = p_segnam
                                          field        = p_field
                                          old_value    = p_old
                                          new_value    = p_new
                                          is_test      = p_test ).
  DATA(docnums) = NEW lcl_idoc_finder( )->find_idocs( selection ).
  DATA(bulk_fix) = NEW lcl_bulk_fix( NEW zcl_idoctor_repository( ) ).
  DATA(results) = bulk_fix->run( docnums = docnums
                                 fix     = fix ).
  NEW lcl_result_list( )->show( results ).
