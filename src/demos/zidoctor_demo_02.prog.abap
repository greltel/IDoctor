" IDoctor demo 02 - load one IDoc, change a field in the segments that match, and save it.
" In test mode nothing is saved; otherwise the IDoc is saved through SAP's IDoc edit interface
" and the demo asks save( ) to commit.
REPORT zidoctor_demo_02.

PARAMETERS p_docnum TYPE edidc-docnum OBLIGATORY.
PARAMETERS p_segnam TYPE edidd-segnam OBLIGATORY.
PARAMETERS p_field TYPE fieldname OBLIGATORY.
PARAMETERS p_old TYPE c LENGTH 70 LOWER CASE.
PARAMETERS p_new TYPE c LENGTH 70 LOWER CASE.
PARAMETERS p_test AS CHECKBOX DEFAULT abap_true.

CLASS lcl_demo DEFINITION FINAL.
  PUBLIC SECTION.
    TYPES:
      BEGIN OF ty_request,
        docnum       TYPE edidc-docnum,
        segment_type TYPE edidd-segnam,
        field        TYPE fieldname,
        "! Only segments whose field has this content; every segment of the type when initial
        old_value    TYPE string,
        new_value    TYPE string,
        is_test      TYPE abap_bool,
      END OF ty_request.

    METHODS constructor
      IMPORTING repository TYPE REF TO zif_idoctor_repository.

    METHODS run
      IMPORTING request TYPE ty_request
      RAISING   zcx_idoctor_error.

  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_change,
        segment_type TYPE edidd-segnam,
        old_value    TYPE string,
        new_value    TYPE string,
      END OF ty_change.
    TYPES ty_changes TYPE STANDARD TABLE OF ty_change WITH EMPTY KEY.
    CONSTANTS:
      BEGIN OF column,
        old_value TYPE lvc_fname VALUE 'OLD_VALUE',
        new_value TYPE lvc_fname VALUE 'NEW_VALUE',
      END OF column.

    DATA repository TYPE REF TO zif_idoctor_repository.

    METHODS segments_to_change
      IMPORTING idoc          TYPE REF TO zcl_idoctor
                request       TYPE ty_request
      RETURNING VALUE(result) TYPE zcl_idoctor=>ty_segments
      RAISING   zcx_idoctor_error.

    METHODS show
      IMPORTING changes TYPE ty_changes.

    METHODS set_title
      IMPORTING columns TYPE REF TO cl_salv_columns_table
                name    TYPE lvc_fname
                title   TYPE csequence
      RAISING   cx_salv_not_found.
ENDCLASS.


CLASS lcl_demo IMPLEMENTATION.

  METHOD constructor.
    me->repository = repository.
  ENDMETHOD.


  METHOD run.
    DATA changes TYPE ty_changes.

    DATA(idoc) = repository->load( request-docnum ).
    DATA(segments) = segments_to_change( idoc    = idoc
                                         request = request ).
    LOOP AT segments INTO DATA(segment).
      DATA(old_value) = segment->get_value( request-field ).
      segment->set_value( field = request-field
                          value = request-new_value ).
      INSERT VALUE #( segment_type = segment->name( )
                      old_value    = old_value
                      new_value    = request-new_value ) INTO TABLE changes.
    ENDLOOP.

    IF request-is_test = abap_false AND changes IS NOT INITIAL.
      repository->save( idoc     = idoc
                        settings = VALUE #( commit = abap_true ) ).
      MESSAGE s060(zidoctor) WITH request-docnum.
    ENDIF.
    show( changes ).
  ENDMETHOD.


  METHOD segments_to_change.
    IF request-old_value IS INITIAL.
      result = idoc->find_all( request-segment_type ).
    ELSE.
      result = idoc->find_all( name  = request-segment_type
                               field = request-field
                               value = request-old_value ).
    ENDIF.
  ENDMETHOD.


  METHOD show.
    DATA(rows) = changes.
    TRY.
        cl_salv_table=>factory( IMPORTING r_salv_table = DATA(alv)
                                CHANGING  t_table      = rows ).
        DATA(columns) = alv->get_columns( ).
        columns->set_optimize( ).
        set_title( columns = columns
                   name    = column-old_value
                   title   = TEXT-001 ).
        set_title( columns = columns
                   name    = column-new_value
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


START-OF-SELECTION.
  TRY.
      DATA(request) = VALUE lcl_demo=>ty_request( docnum       = p_docnum
                                                  segment_type = p_segnam
                                                  field        = p_field
                                                  old_value    = p_old
                                                  new_value    = p_new
                                                  is_test      = p_test ).
      NEW lcl_demo( NEW zcl_idoctor_repository( ) )->run( request ).
    CATCH zcx_idoctor_error INTO DATA(error).
      ROLLBACK WORK.
      MESSAGE error TYPE 'S' DISPLAY LIKE 'E'.
  ENDTRY.
