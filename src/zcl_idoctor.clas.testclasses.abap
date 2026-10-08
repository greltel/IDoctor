"! Syntax and data records of a small IDoc type, built in memory:
"! Z1HEAD 1..1, Z1PARTNER 0..5, Z1ITEM 1..999 (children Z1ITEMTEXT 0..9, Z1SCHEDULE 1..1), Z1TOTAL 0..1
CLASS lth_idoc DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    CLASS-METHODS syntax
      RETURNING VALUE(result) TYPE zcl_idoctor=>ty_syntax.

    "! A valid IDoc: head, partner, two items with their children, total
    CLASS-METHODS valid_records
      RETURNING VALUE(result) TYPE zcl_idoctor=>ty_data_records.
ENDCLASS.


CLASS lth_idoc IMPLEMENTATION.

  METHOD syntax.
    result = VALUE #(
      idoc_type = 'ZTEST_ORDERS'
      segments  = VALUE #(
        ( segment_type = 'Z1HEAD'     position = 1 hierarchy_level = '02' min_occurrence = 1 max_occurrence = 1 )
        ( segment_type = 'Z1PARTNER'  position = 2 hierarchy_level = '02' min_occurrence = 0 max_occurrence = 5 )
        ( segment_type = 'Z1ITEM'     position = 3 hierarchy_level = '02' min_occurrence = 1 max_occurrence = 999 )
        ( segment_type = 'Z1ITEMTEXT' position = 4 hierarchy_level = '03' min_occurrence = 0 max_occurrence = 9
          parent_type  = 'Z1ITEM' )
        ( segment_type = 'Z1SCHEDULE' position = 5 hierarchy_level = '03' min_occurrence = 1 max_occurrence = 1
          parent_type  = 'Z1ITEM' )
        ( segment_type = 'Z1TOTAL'    position = 6 hierarchy_level = '02' min_occurrence = 0 max_occurrence = 1 ) )
      fields    = VALUE #(
        ( segment_type = 'Z1HEAD'     field_name = 'DOCNO'  offset = 0  length = 10 )
        ( segment_type = 'Z1HEAD'     field_name = 'CURCY'  offset = 10 length = 3 )
        ( segment_type = 'Z1PARTNER'  field_name = 'PARVW'  offset = 0  length = 3 )
        ( segment_type = 'Z1PARTNER'  field_name = 'PARTN'  offset = 3  length = 10 )
        ( segment_type = 'Z1ITEM'     field_name = 'POSNR'  offset = 0  length = 6 )
        ( segment_type = 'Z1ITEM'     field_name = 'MATNR'  offset = 6  length = 18 )
        ( segment_type = 'Z1ITEMTEXT' field_name = 'TDLINE' offset = 0  length = 70 )
        ( segment_type = 'Z1SCHEDULE' field_name = 'EDATU'  offset = 0  length = 8 )
        ( segment_type = 'Z1TOTAL'    field_name = 'SUMME'  offset = 0  length = 18 ) ) ).
  ENDMETHOD.


  METHOD valid_records.
    result = VALUE #( ( segnam = 'Z1HEAD'     sdata = 'PO-4711   EUR' )
                      ( segnam = 'Z1PARTNER'  sdata = 'AG 0000004711' )
                      ( segnam = 'Z1ITEM'     sdata = '000010MAT-A' )
                      ( segnam = 'Z1ITEMTEXT' sdata = 'Handle with care' )
                      ( segnam = 'Z1SCHEDULE' sdata = '20261231' )
                      ( segnam = 'Z1ITEM'     sdata = '000020MAT-B' )
                      ( segnam = 'Z1SCHEDULE' sdata = '20270115' )
                      ( segnam = 'Z1TOTAL'    sdata = '100.00' ) ).
  ENDMETHOD.

ENDCLASS.


CLASS ltc_idoctor DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    METHODS when_created_then_empty FOR TESTING RAISING cx_static_check.
    METHODS given_empty_syntax_raises FOR TESTING RAISING cx_static_check.
    METHODS when_from_edidd_then_tree FOR TESTING RAISING cx_static_check.
    METHODS given_unknown_type_raises FOR TESTING RAISING cx_static_check.
    METHODS given_orphan_then_raises FOR TESTING RAISING cx_static_check.
    METHODS given_other_type_raises FOR TESTING RAISING cx_static_check.
    METHODS given_no_edidd_then_raises FOR TESTING RAISING cx_static_check.
    METHODS when_to_edidd_then_numbered FOR TESTING RAISING cx_static_check.
    METHODS when_round_trip_then_same FOR TESTING RAISING cx_static_check.
    METHODS when_added_then_syntax_order FOR TESTING RAISING cx_static_check.
    METHODS given_max_reached_add_raises FOR TESTING RAISING cx_static_check.
    METHODS given_valid_then_no_findings FOR TESTING RAISING cx_static_check.
    METHODS given_no_head_then_finding FOR TESTING RAISING cx_static_check.
    METHODS given_two_heads_then_finding FOR TESTING RAISING cx_static_check.
    METHODS given_bad_order_then_finding FOR TESTING RAISING cx_static_check.
    METHODS when_found_by_value_then_hit FOR TESTING RAISING cx_static_check.
    METHODS when_nothing_found_raises FOR TESTING RAISING cx_static_check.
    METHODS given_unknown_field_raises FOR TESTING RAISING cx_static_check.

    METHODS valid_idoc
      RETURNING VALUE(result) TYPE REF TO zcl_idoctor
      RAISING   zcx_idoctor_error.

    METHODS names_of
      IMPORTING segments      TYPE zcl_idoctor=>ty_segments
      RETURNING VALUE(result) TYPE string_table.
ENDCLASS.


CLASS ltc_idoctor IMPLEMENTATION.

  METHOD when_created_then_empty.
    DATA(idoc) = zcl_idoctor=>create( lth_idoc=>syntax( ) ).

    cl_abap_unit_assert=>assert_initial( act = idoc->to_edidd( )
                                         msg = `A new IDoc must have no segments` ).
    cl_abap_unit_assert=>assert_equals( act = idoc->control( )-idoctp
                                        exp = 'ZTEST_ORDERS'
                                        msg = `A new IDoc must carry the IDoc type of its syntax` ).
  ENDMETHOD.


  METHOD given_empty_syntax_raises.
    TRY.
        zcl_idoctor=>create( VALUE #( idoc_type = 'ZTEST_ORDERS' ) ).
        cl_abap_unit_assert=>fail( msg = `A syntax without segments must be rejected` ).
      CATCH zcx_idoctor_error INTO DATA(error).
        cl_abap_unit_assert=>assert_equals( act = error->if_t100_message~t100key-msgno
                                            exp = '013'
                                            msg = `Wrong error - expected: syntax contains no segments` ).
    ENDTRY.
  ENDMETHOD.


  METHOD when_from_edidd_then_tree.
    DATA(idoc) = valid_idoc( ).

    DATA(items) = idoc->segments( 'Z1ITEM' ).
    cl_abap_unit_assert=>assert_equals( act = names_of( items[ 1 ]->children( ) )
                                        exp = VALUE string_table( ( `Z1ITEMTEXT` ) ( `Z1SCHEDULE` ) )
                                        msg = `Text and schedule line must hang under the first item` ).
    cl_abap_unit_assert=>assert_equals( act = lines( idoc->segments( ) )
                                        exp = 5
                                        msg = `Head, partner, two items and total are the top level` ).
  ENDMETHOD.


  METHOD given_unknown_type_raises.
    DATA(records) = lth_idoc=>valid_records( ).
    INSERT VALUE #( segnam = 'Z1UNKNOWN' ) INTO TABLE records.

    TRY.
        zcl_idoctor=>from_edidd( syntax = lth_idoc=>syntax( )
                                 data   = records ).
        cl_abap_unit_assert=>fail( msg = `A segment type outside the syntax must be rejected` ).
      CATCH zcx_idoctor_error INTO DATA(error).
        cl_abap_unit_assert=>assert_equals( act = error->if_t100_message~t100key-msgno
                                            exp = '001'
                                            msg = `Wrong error - expected: segment type not defined` ).
    ENDTRY.
  ENDMETHOD.


  METHOD given_orphan_then_raises.
    DATA(records) = VALUE zcl_idoctor=>ty_data_records( ( segnam = 'Z1HEAD' )
                                                        ( segnam = 'Z1ITEMTEXT' ) ).

    TRY.
        zcl_idoctor=>from_edidd( syntax = lth_idoc=>syntax( )
                                 data   = records ).
        cl_abap_unit_assert=>fail( msg = `A child without its parent before it must be rejected` ).
      CATCH zcx_idoctor_error INTO DATA(error).
        cl_abap_unit_assert=>assert_equals( act = error->if_t100_message~t100key-msgno
                                            exp = '002'
                                            msg = `Wrong error - expected: no parent segment before it` ).
    ENDTRY.
  ENDMETHOD.


  METHOD given_other_type_raises.
    TRY.
        zcl_idoctor=>from_edidd( syntax  = lth_idoc=>syntax( )
                                 data    = lth_idoc=>valid_records( )
                                 control = VALUE #( idoctp = 'ORDERS05' ) ).
        cl_abap_unit_assert=>fail( msg = `A control record of another IDoc type must be rejected` ).
      CATCH zcx_idoctor_error INTO DATA(error).
        cl_abap_unit_assert=>assert_equals( act = error->if_t100_message~t100key-msgno
                                            exp = '010'
                                            msg = `Wrong error - expected: IDoc type does not match` ).
    ENDTRY.
  ENDMETHOD.


  METHOD given_no_edidd_then_raises.
    DATA(lines_of_text) = VALUE string_table( ( `Z1HEAD` ) ).

    TRY.
        zcl_idoctor=>from_edidd( syntax = lth_idoc=>syntax( )
                                 data   = lines_of_text ).
        cl_abap_unit_assert=>fail( msg = `A table that is no EDIDD table must be rejected` ).
      CATCH zcx_idoctor_error INTO DATA(error).
        cl_abap_unit_assert=>assert_equals( act = error->if_t100_message~t100key-msgno
                                            exp = '014'
                                            msg = `Wrong error - expected: EDIDD data expected` ).
    ENDTRY.
  ENDMETHOD.


  METHOD when_to_edidd_then_numbered.
    DATA(idoc) = zcl_idoctor=>from_edidd( syntax  = lth_idoc=>syntax( )
                                          data    = lth_idoc=>valid_records( )
                                          control = VALUE #( docnum = '0000000000004711' ) ).

    DATA(records) = idoc->to_edidd( ).

    " record 4 is the text of the first item, which is record 3
    cl_abap_unit_assert=>assert_equals( act = records[ 4 ]-segnum
                                        exp = '000004'
                                        msg = `SEGNUM must count the records in document order` ).
    cl_abap_unit_assert=>assert_equals( act = records[ 4 ]-psgnum
                                        exp = '000003'
                                        msg = `PSGNUM must point to the SEGNUM of the parent` ).
    cl_abap_unit_assert=>assert_equals( act = records[ 4 ]-hlevel
                                        exp = '03'
                                        msg = `HLEVEL must come from the syntax` ).
    cl_abap_unit_assert=>assert_equals( act = records[ 1 ]-psgnum
                                        exp = '000000'
                                        msg = `A top-level segment has PSGNUM 000000` ).
    cl_abap_unit_assert=>assert_equals( act = records[ 8 ]-docnum
                                        exp = '0000000000004711'
                                        msg = `DOCNUM must come from the control record` ).
  ENDMETHOD.


  METHOD when_round_trip_then_same.
    DATA(original) = lth_idoc=>valid_records( ).

    DATA(records) = zcl_idoctor=>from_edidd( syntax = lth_idoc=>syntax( )
                                             data   = original )->to_edidd( ).

    cl_abap_unit_assert=>assert_equals(
      act = VALUE string_table( FOR record IN records ( |{ record-segnam }:{ record-sdata }| ) )
      exp = VALUE string_table( FOR expected IN original ( |{ expected-segnam }:{ expected-sdata }| ) )
      msg = `from_edidd( ) followed by to_edidd( ) must keep segments, order and data` ).
  ENDMETHOD.


  METHOD when_added_then_syntax_order.
    DATA(idoc) = zcl_idoctor=>create( lth_idoc=>syntax( ) ).

    idoc->add( 'Z1ITEM' ).
    idoc->add( 'Z1HEAD' ).
    idoc->add( 'Z1PARTNER' ).

    cl_abap_unit_assert=>assert_equals( act = names_of( idoc->segments( ) )
                                        exp = VALUE string_table( ( `Z1HEAD` ) ( `Z1PARTNER` ) ( `Z1ITEM` ) )
                                        msg = `add( ) must place segments in the order of the syntax` ).
  ENDMETHOD.


  METHOD given_max_reached_add_raises.
    DATA(idoc) = zcl_idoctor=>create( lth_idoc=>syntax( ) ).
    idoc->add( 'Z1HEAD' ).

    TRY.
        idoc->add( 'Z1HEAD' ).
        cl_abap_unit_assert=>fail( msg = `A second head must be rejected - the syntax allows one` ).
      CATCH zcx_idoctor_error INTO DATA(error).
        cl_abap_unit_assert=>assert_equals( act = error->if_t100_message~t100key-msgno
                                            exp = '004'
                                            msg = `Wrong error - expected: at most 1 allowed` ).
    ENDTRY.
  ENDMETHOD.


  METHOD given_valid_then_no_findings.
    DATA(idoc) = valid_idoc( ).

    cl_abap_unit_assert=>assert_initial( act = idoc->validate( )
                                         msg = `A valid IDoc must have no findings` ).
  ENDMETHOD.


  METHOD given_no_head_then_finding.
    DATA(records) = lth_idoc=>valid_records( ).
    DELETE records WHERE segnam = 'Z1HEAD'.
    DATA(idoc) = zcl_idoctor=>from_edidd( syntax = lth_idoc=>syntax( )
                                          data   = records ).

    DATA(findings) = idoc->validate( ).

    cl_abap_unit_assert=>assert_equals( act = lines( findings )
                                        exp = 1
                                        msg = `The missing mandatory head must be the one finding` ).
    cl_abap_unit_assert=>assert_equals( act = findings[ 1 ]-msgno
                                        exp = '020'
                                        msg = `Wrong finding - expected: at least 1 required` ).
    cl_abap_unit_assert=>assert_not_bound( act = findings[ 1 ]-segment
                                           msg = `A missing top-level segment concerns the IDoc itself` ).
  ENDMETHOD.


  METHOD given_two_heads_then_finding.
    DATA(records) = lth_idoc=>valid_records( ).
    INSERT VALUE #( segnam = 'Z1HEAD' sdata = 'PO-4712' ) INTO records INDEX 2.
    DATA(idoc) = zcl_idoctor=>from_edidd( syntax = lth_idoc=>syntax( )
                                          data   = records ).

    DATA(findings) = idoc->validate( ).

    cl_abap_unit_assert=>assert_equals( act = findings[ 1 ]-msgno
                                        exp = '021'
                                        msg = `Wrong finding - expected: at most 1 allowed` ).
    cl_abap_unit_assert=>assert_equals( act = findings[ 1 ]-segment->get_value( 'DOCNO' )
                                        exp = `PO-4712`
                                        msg = `The finding must point to the head that is too many` ).
  ENDMETHOD.


  METHOD given_bad_order_then_finding.
    DATA(records) = lth_idoc=>valid_records( ).
    DELETE records WHERE segnam = 'Z1TOTAL'.
    INSERT VALUE #( segnam = 'Z1TOTAL' sdata = '100.00' ) INTO records INDEX 1.
    DATA(idoc) = zcl_idoctor=>from_edidd( syntax = lth_idoc=>syntax( )
                                          data   = records ).

    DATA(findings) = idoc->validate( ).

    cl_abap_unit_assert=>assert_equals( act = lines( findings )
                                        exp = 1
                                        msg = `The total in front of the head must be the one finding` ).
    cl_abap_unit_assert=>assert_equals( act = findings[ 1 ]-msgno
                                        exp = '022'
                                        msg = `Wrong finding - expected: out of order` ).
  ENDMETHOD.


  METHOD when_found_by_value_then_hit.
    DATA(idoc) = valid_idoc( ).

    DATA(item) = idoc->find_first( name  = 'Z1ITEM'
                                   field = 'MATNR'
                                   value = 'MAT-B' ).

    cl_abap_unit_assert=>assert_equals( act = item->get_value( 'POSNR' )
                                        exp = `000020`
                                        msg = `The item with material MAT-B is item 000020` ).
  ENDMETHOD.


  METHOD when_nothing_found_raises.
    DATA(idoc) = valid_idoc( ).

    TRY.
        idoc->find_first( name  = 'Z1ITEM'
                          field = 'MATNR'
                          value = 'MAT-X' ).
        cl_abap_unit_assert=>fail( msg = `find_first( ) without a match must raise` ).
      CATCH zcx_idoctor_error INTO DATA(error).
        cl_abap_unit_assert=>assert_equals( act = error->if_t100_message~t100key-msgno
                                            exp = '012'
                                            msg = `Wrong error - expected: no segment with that value` ).
    ENDTRY.
  ENDMETHOD.


  METHOD given_unknown_field_raises.
    DATA(idoc) = valid_idoc( ).

    TRY.
        idoc->find_all( name  = 'Z1ITEM'
                        field = 'KUNNR'
                        value = '4711' ).
        cl_abap_unit_assert=>fail( msg = `A field outside the segment definition must be rejected` ).
      CATCH zcx_idoctor_error INTO DATA(error).
        cl_abap_unit_assert=>assert_equals( act = error->if_t100_message~t100key-msgno
                                            exp = '006'
                                            msg = `Wrong error - expected: field not defined` ).
    ENDTRY.
  ENDMETHOD.


  METHOD valid_idoc.
    result = zcl_idoctor=>from_edidd( syntax = lth_idoc=>syntax( )
                                      data   = lth_idoc=>valid_records( ) ).
  ENDMETHOD.


  METHOD names_of.
    result = VALUE #( FOR segment IN segments ( |{ segment->name( ) }| ) ).
  ENDMETHOD.

ENDCLASS.
