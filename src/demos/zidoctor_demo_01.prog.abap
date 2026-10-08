" IDoctor demo 01 - build an ORDERS05 IDoc in memory, check it against its syntax and show the
" EDIDD records it produces. Nothing is read from or written to IDoc tables.
REPORT zidoctor_demo_01.

CLASS lcl_demo DEFINITION FINAL.
  PUBLIC SECTION.
    METHODS constructor
      IMPORTING repository TYPE REF TO zif_idoctor_repository.

    METHODS run
      RAISING zcx_idoctor_error.

  PRIVATE SECTION.
    CONSTANTS idoc_type TYPE edidc-idoctp VALUE 'ORDERS05'.
    CONSTANTS:
      BEGIN OF sample,
        currency      TYPE c LENGTH 3 VALUE 'EUR',
        order_type    TYPE c LENGTH 4 VALUE 'NB',
        sold_to_role  TYPE c LENGTH 3 VALUE 'AG',
        sold_to       TYPE c LENGTH 10 VALUE '0000004711',
        item_number   TYPE c LENGTH 6 VALUE '000010',
        quantity      TYPE c LENGTH 15 VALUE '5',
        unit          TYPE c LENGTH 3 VALUE 'PCE',
        material_role TYPE c LENGTH 3 VALUE '002',
        material      TYPE c LENGTH 35 VALUE 'MAT-4711',
      END OF sample.

    DATA repository TYPE REF TO zif_idoctor_repository.

    METHODS build_order
      IMPORTING idoc TYPE REF TO zcl_idoctor
      RAISING   zcx_idoctor_error.

    METHODS show
      IMPORTING idoc TYPE REF TO zcl_idoctor.
ENDCLASS.


CLASS lcl_demo IMPLEMENTATION.

  METHOD constructor.
    me->repository = repository.
  ENDMETHOD.


  METHOD run.
    DATA(idoc) = zcl_idoctor=>create( repository->read_syntax( idoc_type ) ).
    build_order( idoc ).
    show( idoc ).
  ENDMETHOD.


  METHOD build_order.
    " typed access: the DDIC structure of the segment type
    DATA header TYPE e1edk01.
    header-curcy = sample-currency.
    header-bsart = sample-order_type.
    idoc->add( 'E1EDK01' )->set_data( header ).

    " field access: by field name, checked against the syntax
    DATA(sold_to) = idoc->add( 'E1EDKA1' ).
    sold_to->set_value( field = 'PARVW'
                        value = sample-sold_to_role ).
    sold_to->set_value( field = 'PARTN'
                        value = sample-sold_to ).

    DATA(item) = idoc->add( 'E1EDP01' ).
    item->set_value( field = 'POSEX'
                     value = sample-item_number ).
    item->set_value( field = 'MENGE'
                     value = sample-quantity ).
    item->set_value( field = 'MENEE'
                     value = sample-unit ).

    DATA(material) = item->add( 'E1EDP19' ).
    material->set_value( field = 'QUALF'
                         value = sample-material_role ).
    material->set_value( field = 'IDTNR'
                         value = sample-material ).
  ENDMETHOD.


  METHOD show.
    DATA(records) = idoc->to_edidd( ).
    DATA(findings) = idoc->validate( ).
    IF findings IS NOT INITIAL.
      DATA(finding) = findings[ 1 ].
      MESSAGE ID finding-msgid TYPE 'S' NUMBER finding-msgno
        WITH finding-msgv1 finding-msgv2 finding-msgv3 finding-msgv4 DISPLAY LIKE 'W'.
    ENDIF.
    TRY.
        cl_salv_table=>factory( IMPORTING r_salv_table = DATA(alv)
                                CHANGING  t_table      = records ).
        alv->get_columns( )->set_optimize( ).
        alv->display( ).
      CATCH cx_salv_msg INTO DATA(error).
        MESSAGE error TYPE 'S' DISPLAY LIKE 'E'.
    ENDTRY.
  ENDMETHOD.

ENDCLASS.


START-OF-SELECTION.
  TRY.
      NEW lcl_demo( NEW zcl_idoctor_repository( ) )->run( ).
    CATCH zcx_idoctor_error INTO DATA(error).
      MESSAGE error TYPE 'S' DISPLAY LIKE 'E'.
  ENDTRY.
