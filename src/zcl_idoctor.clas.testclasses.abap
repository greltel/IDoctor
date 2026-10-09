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
    METHODS when_flat_then_fixed_records FOR TESTING RAISING cx_static_check.
    METHODS when_flat_then_line_per_record FOR TESTING RAISING cx_static_check.
    METHODS given_definition_flat_uses_it FOR TESTING RAISING cx_static_check.
    METHODS when_xml_then_children_nested FOR TESTING RAISING cx_static_check.
    METHODS when_xml_then_control_record FOR TESTING RAISING cx_static_check.
    METHODS given_empty_field_xml_omits FOR TESTING RAISING cx_static_check.
    METHODS given_special_chars_xml_escape FOR TESTING RAISING cx_static_check.
    METHODS when_numbered_then_as_edidd FOR TESTING RAISING cx_static_check.
    METHODS given_short_number_then_found FOR TESTING RAISING cx_static_check.
    METHODS given_unknown_number_raises FOR TESTING RAISING cx_static_check.
    METHODS when_found_without_type_all FOR TESTING RAISING cx_static_check.
    METHODS given_field_without_type_raise FOR TESTING RAISING cx_static_check.
    METHODS when_inserted_then_renumbered FOR TESTING RAISING cx_static_check.
    METHODS when_removed_then_subtree_gone FOR TESTING RAISING cx_static_check.
    METHODS given_no_schedule_then_finding FOR TESTING RAISING cx_static_check.
    METHODS given_namespace_xml_names FOR TESTING RAISING cx_static_check.

    METHODS valid_idoc
      RETURNING VALUE(result) TYPE REF TO zcl_idoctor
      RAISING   zcx_idoctor_error.

    METHODS names_of
      IMPORTING segments      TYPE zcl_idoctor=>ty_segments
      RETURNING VALUE(result) TYPE string_table.

    "! One line per record: SEGNUM, PSGNUM and segment type
    METHODS numbering_of
      IMPORTING records       TYPE zcl_idoctor=>ty_data_records
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


  METHOD when_flat_then_fixed_records.
    DATA(idoc) = valid_idoc( ).

    DATA(file) = idoc->to_flat_file( `` ).

    " EDI_DC40 is 524 characters, EDI_DD40 1063 - one control record and eight data records
    cl_abap_unit_assert=>assert_equals( act = strlen( file )
                                        exp = 524 + 8 * 1063
                                        msg = `Records must be padded to the full length of EDI_DC40 / EDI_DD40` ).
    cl_abap_unit_assert=>assert_equals( act = substring( val = file
                                                         len = 8 )
                                        exp = `EDI_DC40`
                                        msg = `The file must start with the control record` ).
    cl_abap_unit_assert=>assert_equals( act = condense( substring( val = file
                                                                   off = 524
                                                                   len = 30 ) )
                                        exp = `Z1HEAD`
                                        msg = `The first data record must carry the first segment` ).
  ENDMETHOD.


  METHOD when_flat_then_line_per_record.
    DATA(idoc) = valid_idoc( ).

    DATA(file) = idoc->to_flat_file( ).

    cl_abap_unit_assert=>assert_equals( act = count( val = file
                                                     sub = cl_abap_char_utilities=>newline )
                                        exp = 9
                                        msg = `Every record - control and eight segments - must end in a line break` ).
  ENDMETHOD.


  METHOD given_definition_flat_uses_it.
    DATA(syntax) = lth_idoc=>syntax( ).
    DATA(head) = REF #( syntax-segments[ segment_type = 'Z1HEAD' ] ).
    head->definition = 'Z2HEAD001'.
    DATA(idoc) = zcl_idoctor=>from_edidd( syntax = syntax
                                          data   = lth_idoc=>valid_records( ) ).

    DATA(file) = idoc->to_flat_file( `` ).

    cl_abap_unit_assert=>assert_equals( act = condense( substring( val = file
                                                                   off = 524
                                                                   len = 30 ) )
                                        exp = `Z2HEAD001`
                                        msg = `A file must carry the segment definition where the syntax knows it` ).
  ENDMETHOD.


  METHOD when_xml_then_children_nested.
    DATA(idoc) = valid_idoc( ).

    DATA(xml) = idoc->to_xml( ).

    DATA(item_start) = find( val = xml
                             sub = `<Z1ITEM SEGMENT="1">` ).
    DATA(text) = find( val = xml
                       sub = `<TDLINE>Handle with care</TDLINE>` ).
    DATA(item_end) = find( val = xml
                           sub = `</Z1ITEM>` ).
    cl_abap_unit_assert=>assert_true( act = xsdbool( item_start >= 0 AND item_start < text AND text < item_end )
                                      msg = `The item text must be nested in the first item element` ).
    cl_abap_unit_assert=>assert_equals( act = find( val = xml
                                                    sub = `<ZTEST_ORDERS>` )
                                        exp = find( val = xml
                                                    sub = `<ZTEST_ORDERS` )
                                        msg = `The root element must be named after the IDoc type` ).
  ENDMETHOD.


  METHOD when_xml_then_control_record.
    DATA(idoc) = zcl_idoctor=>from_edidd( syntax  = lth_idoc=>syntax( )
                                          data    = lth_idoc=>valid_records( )
                                          control = VALUE #( docnum = '0000000000004711' ) ).

    DATA(xml) = idoc->to_xml( ).

    cl_abap_unit_assert=>assert_true( act = xsdbool( xml CS `<DOCNUM>0000000000004711</DOCNUM>`
                                                 AND xml CS `<IDOCTYP>ZTEST_ORDERS</IDOCTYP>`
                                                 AND xml CS `<TABNAM>EDI_DC40</TABNAM>` )
                                      msg = `The control record must appear as EDI_DC40 with its fields` ).
  ENDMETHOD.


  METHOD given_empty_field_xml_omits.
    DATA(idoc) = zcl_idoctor=>create( lth_idoc=>syntax( ) ).
    idoc->add( 'Z1HEAD' )->set_value( field = 'DOCNO'
                                      value = 'PO-1' ).

    DATA(xml) = idoc->to_xml( ).

    cl_abap_unit_assert=>assert_true( act = xsdbool( xml CS `<DOCNO>PO-1</DOCNO>` AND xml NS `<CURCY>` )
                                      msg = `Filled fields must be written, empty ones left out` ).
  ENDMETHOD.


  METHOD given_special_chars_xml_escape.
    DATA(idoc) = zcl_idoctor=>create( lth_idoc=>syntax( ) ).
    idoc->add( 'Z1HEAD' )->set_value( field = 'DOCNO'
                                      value = 'A&B<C' ).

    DATA(xml) = idoc->to_xml( ).

    cl_abap_unit_assert=>assert_true( act = xsdbool( xml CS `<DOCNO>A&amp;B&lt;C</DOCNO>` )
                                      msg = `Characters with a meaning in XML must be escaped` ).
  ENDMETHOD.


  METHOD when_numbered_then_as_edidd.
    DATA(idoc) = valid_idoc( ).

    DATA(records) = idoc->to_edidd( ).

    LOOP AT records INTO DATA(record).
      DATA(segment) = idoc->find_by_number( record-segnum ).
      cl_abap_unit_assert=>assert_equals( act = segment->name( )
                                          exp = record-segnam
                                          msg = |Segment { record-segnum } must be the one to_edidd( ) numbers so| ).
      cl_abap_unit_assert=>assert_equals( act = segment->number( )
                                          exp = record-segnum
                                          msg = |number( ) must give { record-segnum } back| ).
    ENDLOOP.
  ENDMETHOD.


  METHOD given_short_number_then_found.
    DATA(idoc) = valid_idoc( ).

    DATA(item) = idoc->find_by_number( `6` ).

    cl_abap_unit_assert=>assert_equals( act = item->get_value( 'POSNR' )
                                        exp = `000020`
                                        msg = `Number 6 without leading zeros must find the second item` ).
  ENDMETHOD.


  METHOD given_unknown_number_raises.
    DATA(idoc) = valid_idoc( ).

    TRY.
        idoc->find_by_number( '000099' ).
        cl_abap_unit_assert=>fail( msg = `A number beyond the last segment must raise` ).
      CATCH zcx_idoctor_error INTO DATA(error).
        cl_abap_unit_assert=>assert_equals( act = error->if_t100_message~t100key-msgno
                                            exp = '016'
                                            msg = `Wrong error - expected: no segment with that number` ).
    ENDTRY.
  ENDMETHOD.


  METHOD when_found_without_type_all.
    DATA(idoc) = valid_idoc( ).
    DATA(records) = idoc->to_edidd( ).
    DATA(expected) = VALUE string_table( FOR record IN records ( |{ record-segnam }| ) ).

    DATA(all) = idoc->find_all( ).

    cl_abap_unit_assert=>assert_equals( act = names_of( all )
                                        exp = expected
                                        msg = `find_all( ) without a type must list every segment in document order` ).
    cl_abap_unit_assert=>assert_equals( act = lines( idoc->find_all( 'Z1ITEM' ) )
                                        exp = 2
                                        msg = `A type passed without parameter name must still filter by type` ).
  ENDMETHOD.


  METHOD given_field_without_type_raise.
    DATA(idoc) = valid_idoc( ).

    TRY.
        idoc->find_all( field = 'MATNR'
                        value = 'MAT-A' ).
        cl_abap_unit_assert=>fail( msg = `A field without a segment type must be rejected` ).
      CATCH zcx_idoctor_error INTO DATA(error).
        cl_abap_unit_assert=>assert_equals( act = error->if_t100_message~t100key-msgno
                                            exp = '017'
                                            msg = `Wrong error - expected: field needs a segment type` ).
    ENDTRY.
  ENDMETHOD.


  METHOD when_inserted_then_renumbered.
    " the user exit case: a partner goes in front of the items, which move with their children
    DATA(idoc) = valid_idoc( ).
    DATA(ship_to) = idoc->find_first( 'Z1PARTNER' )->insert_after( 'Z1PARTNER' ).

    DATA(records) = idoc->to_edidd( ).

    cl_abap_unit_assert=>assert_equals( act = numbering_of( records )
                                        exp = VALUE string_table( ( `000001 000000 Z1HEAD` )
                                                                  ( `000002 000000 Z1PARTNER` )
                                                                  ( `000003 000000 Z1PARTNER` )
                                                                  ( `000004 000000 Z1ITEM` )
                                                                  ( `000005 000004 Z1ITEMTEXT` )
                                                                  ( `000006 000004 Z1SCHEDULE` )
                                                                  ( `000007 000000 Z1ITEM` )
                                                                  ( `000008 000007 Z1SCHEDULE` )
                                                                  ( `000009 000000 Z1TOTAL` ) )
                                        msg = `SEGNUM after the new partner and PSGNUM of moved parents must move up` ).
    cl_abap_unit_assert=>assert_equals( act = ship_to->number( )
                                        exp = '000003'
                                        msg = `The new partner must directly follow the existing one` ).
  ENDMETHOD.


  METHOD when_removed_then_subtree_gone.
    DATA(idoc) = valid_idoc( ).

    idoc->find_first( 'Z1ITEM' )->remove( ).

    cl_abap_unit_assert=>assert_equals( act = numbering_of( idoc->to_edidd( ) )
                                        exp = VALUE string_table( ( `000001 000000 Z1HEAD` )
                                                                  ( `000002 000000 Z1PARTNER` )
                                                                  ( `000003 000000 Z1ITEM` )
                                                                  ( `000004 000003 Z1SCHEDULE` )
                                                                  ( `000005 000000 Z1TOTAL` ) )
                                        msg = `The first item must leave with its text and schedule line` ).
    cl_abap_unit_assert=>assert_equals( act = idoc->find_by_number( '000003' )->get_value( 'MATNR' )
                                        exp = `MAT-B`
                                        msg = `The second item must be left` ).
  ENDMETHOD.


  METHOD given_no_schedule_then_finding.
    DATA(records) = lth_idoc=>valid_records( ).
    " the schedule line of the second item - Z1SCHEDULE is mandatory under every item
    DELETE records WHERE segnam = 'Z1SCHEDULE' AND sdata = '20270115'.
    DATA(idoc) = zcl_idoctor=>from_edidd( syntax = lth_idoc=>syntax( )
                                          data   = records ).

    DATA(findings) = idoc->validate( ).

    cl_abap_unit_assert=>assert_equals( act = lines( findings )
                                        exp = 1
                                        msg = `The missing schedule line must be the one finding` ).
    cl_abap_unit_assert=>assert_equals( act = findings[ 1 ]-msgno
                                        exp = '020'
                                        msg = `Wrong finding - expected: at least 1 required` ).
    cl_abap_unit_assert=>assert_equals( act = findings[ 1 ]-segment->get_value( 'POSNR' )
                                        exp = `000020`
                                        msg = `The finding must point to the item that lacks the schedule line` ).
    cl_abap_unit_assert=>assert_equals( act = CONV string( findings[ 1 ]-msgv3 )
                                        exp = `Z1ITEM 000006`
                                        msg = `The text must name the item with its segment number` ).
  ENDMETHOD.


  METHOD given_namespace_xml_names.
    DATA(syntax) = VALUE zcl_idoctor=>ty_syntax(
      idoc_type = 'ZTEST_ORDERS'
      extension = '/ABC/ZTEST_EXT'
      segments  = VALUE #( ( segment_type    = '/ABC/Z1HEAD'
                             position        = 1
                             hierarchy_level = '02'
                             min_occurrence  = 1
                             max_occurrence  = 1 ) )
      fields    = VALUE #( ( segment_type = '/ABC/Z1HEAD' field_name = 'DOCNO' offset = 0 length = 10 ) ) ).
    DATA(idoc) = zcl_idoctor=>create( syntax ).
    idoc->add( '/ABC/Z1HEAD' )->set_value( field = 'DOCNO'
                                           value = 'PO-1' ).

    DATA(xml) = idoc->to_xml( ).

    cl_abap_unit_assert=>assert_true( act = xsdbool( xml CS `<_-ABC_-ZTEST_EXT>` AND xml NS `<ZTEST_ORDERS>` )
                                      msg = `With an extension the root must be named after it, slash as _-` ).
    cl_abap_unit_assert=>assert_true( act = xsdbool( xml CS `<_-ABC_-Z1HEAD SEGMENT="1">`
                                                 AND xml CS `</_-ABC_-Z1HEAD>` )
                                      msg = `A namespace segment must be written with _- for each slash` ).
  ENDMETHOD.


  METHOD valid_idoc.
    result = zcl_idoctor=>from_edidd( syntax = lth_idoc=>syntax( )
                                      data   = lth_idoc=>valid_records( ) ).
  ENDMETHOD.


  METHOD names_of.
    result = VALUE #( FOR segment IN segments ( |{ segment->name( ) }| ) ).
  ENDMETHOD.


  METHOD numbering_of.
    result = VALUE #( FOR record IN records ( |{ record-segnum } { record-psgnum } { record-segnam }| ) ).
  ENDMETHOD.

ENDCLASS.
