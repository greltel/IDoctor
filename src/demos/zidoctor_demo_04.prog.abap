" IDoctor demo 04 - the user exit / BAdI pattern. lcl_order_exit gets a control record and an
" EDIDD table, as an outbound user exit does, and changes the table with IDoctor: when an order
" has a sold-to party (AG) but no ship-to party (WE), it adds the ship-to party with the same
" number. The demo takes the records of an existing ORDERS IDoc and shows them before and after;
" nothing is saved.
REPORT zidoctor_demo_04.

PARAMETERS p_docnum TYPE edidc-docnum OBLIGATORY.

"! The logic a user exit or BAdI method would delegate to
CLASS lcl_order_exit DEFINITION FINAL.
  PUBLIC SECTION.
    METHODS constructor
      IMPORTING repository TYPE REF TO zif_idoctor_repository.

    "! @parameter control | Control record, as the exit gets it
    "! @parameter data    | Data records, as the exit gets them; changed in place
    "! @raising zcx_idoctor_error | The records do not fit their IDoc type
    METHODS add_ship_to
      IMPORTING control TYPE edidc
      CHANGING  data    TYPE zcl_idoctor=>ty_data_records
      RAISING   zcx_idoctor_error.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF partner_segment,
        name   TYPE edidd-segnam VALUE 'E1EDKA1',
        role   TYPE fieldname VALUE 'PARVW',
        number TYPE fieldname VALUE 'PARTN',
      END OF partner_segment.
    CONSTANTS:
      BEGIN OF partner_role,
        sold_to TYPE c LENGTH 2 VALUE 'AG',
        ship_to TYPE c LENGTH 2 VALUE 'WE',
      END OF partner_role.

    DATA repository TYPE REF TO zif_idoctor_repository.
ENDCLASS.


CLASS lcl_order_exit IMPLEMENTATION.

  METHOD constructor.
    me->repository = repository.
  ENDMETHOD.


  METHOD add_ship_to.
    " the repository reads the syntax once per IDoc type, so keep one instance for all calls
    DATA(syntax) = repository->read_syntax( idoc_type = control-idoctp
                                            extension = control-cimtyp ).
    DATA(idoc) = zcl_idoctor=>from_edidd( syntax  = syntax
                                          data    = data
                                          control = control ).
    DATA(sold_to) = idoc->find_all( name  = partner_segment-name
                                    field = partner_segment-role
                                    value = partner_role-sold_to ).
    DATA(ship_to) = idoc->find_all( name  = partner_segment-name
                                    field = partner_segment-role
                                    value = partner_role-ship_to ).
    IF sold_to IS INITIAL OR ship_to IS NOT INITIAL.
      RETURN.
    ENDIF.

    DATA(new_partner) = sold_to[ 1 ]->insert_after( partner_segment-name ).
    new_partner->set_value( field = partner_segment-role
                            value = partner_role-ship_to ).
    new_partner->set_value( field = partner_segment-number
                            value = sold_to[ 1 ]->get_value( partner_segment-number ) ).
    data = idoc->to_edidd( ).
  ENDMETHOD.

ENDCLASS.


CLASS lcl_demo DEFINITION FINAL.
  PUBLIC SECTION.
    METHODS constructor
      IMPORTING repository TYPE REF TO zif_idoctor_repository.

    METHODS run
      IMPORTING docnum TYPE edidc-docnum
      RAISING   zcx_idoctor_error.

  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_row,
        version TYPE string,
        segnum  TYPE edidd-segnum,
        psgnum  TYPE edidd-psgnum,
        hlevel  TYPE edidd-hlevel,
        segnam  TYPE edidd-segnam,
        sdata   TYPE edidd-sdata,
      END OF ty_row.
    TYPES ty_rows TYPE STANDARD TABLE OF ty_row WITH EMPTY KEY.

    DATA repository TYPE REF TO zif_idoctor_repository.

    METHODS show
      IMPORTING before TYPE zcl_idoctor=>ty_data_records
                after  TYPE zcl_idoctor=>ty_data_records.

    METHODS rows_of
      IMPORTING version       TYPE string
                records       TYPE zcl_idoctor=>ty_data_records
      RETURNING VALUE(result) TYPE ty_rows.
ENDCLASS.


CLASS lcl_demo IMPLEMENTATION.

  METHOD constructor.
    me->repository = repository.
  ENDMETHOD.


  METHOD run.
    " stands in for the exit's parameters: the records of an existing IDoc
    DATA(idoc) = repository->load( docnum ).
    DATA(control) = idoc->control( ).
    DATA(before) = idoc->to_edidd( ).
    DATA(after) = before.

    NEW lcl_order_exit( repository )->add_ship_to( EXPORTING control = control
                                                   CHANGING  data    = after ).
    show( before = before
          after  = after ).
  ENDMETHOD.


  METHOD show.
    DATA(rows) = rows_of( version = `before`
                          records = before ).
    DATA(rows_after) = rows_of( version = `after`
                                records = after ).
    INSERT LINES OF rows_after INTO TABLE rows.
    TRY.
        cl_salv_table=>factory( IMPORTING r_salv_table = DATA(alv)
                                CHANGING  t_table      = rows ).
        alv->get_columns( )->set_optimize( ).
        alv->display( ).
      CATCH cx_salv_msg INTO DATA(error).
        MESSAGE error TYPE 'S' DISPLAY LIKE 'E'.
    ENDTRY.
  ENDMETHOD.


  METHOD rows_of.
    LOOP AT records INTO DATA(record).
      DATA(row) = CORRESPONDING ty_row( record ).
      row-version = version.
      INSERT row INTO TABLE result.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.


START-OF-SELECTION.
  TRY.
      NEW lcl_demo( NEW zcl_idoctor_repository( ) )->run( p_docnum ).
    CATCH zcx_idoctor_error INTO DATA(error).
      MESSAGE error TYPE 'S' DISPLAY LIKE 'E'.
  ENDTRY.
