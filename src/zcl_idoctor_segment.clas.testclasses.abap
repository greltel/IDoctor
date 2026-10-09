"! Syntax of a small IDoc type, built in memory:
"! Z1HEAD 1..1, Z1ITEM 1..999 (children Z1ITEMTEXT 0..9, Z1SCHEDULE 1..1), Z1TOTAL 0..1
CLASS lth_idoc DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    CLASS-METHODS syntax
      RETURNING VALUE(result) TYPE zcl_idoctor=>ty_syntax.
ENDCLASS.


CLASS lth_idoc IMPLEMENTATION.

  METHOD syntax.
    result = VALUE #(
      idoc_type = 'ZTEST_ORDERS'
      segments  = VALUE #(
        ( segment_type = 'Z1HEAD'     position = 1 hierarchy_level = '02' min_occurrence = 1 max_occurrence = 1 )
        ( segment_type = 'Z1ITEM'     position = 3 hierarchy_level = '02' min_occurrence = 1 max_occurrence = 999 )
        ( segment_type = 'Z1ITEMTEXT' position = 4 hierarchy_level = '03' min_occurrence = 0 max_occurrence = 9
          parent_type  = 'Z1ITEM' )
        ( segment_type = 'Z1SCHEDULE' position = 5 hierarchy_level = '03' min_occurrence = 1 max_occurrence = 1
          parent_type  = 'Z1ITEM' )
        ( segment_type = 'Z1TOTAL'    position = 6 hierarchy_level = '02' min_occurrence = 0 max_occurrence = 1 ) )
      fields    = VALUE #(
        ( segment_type = 'Z1HEAD'     field_name = 'DOCNO'  offset = 0 length = 10 )
        ( segment_type = 'Z1ITEM'     field_name = 'POSNR'  offset = 0 length = 6 )
        ( segment_type = 'Z1ITEM'     field_name = 'MATNR'  offset = 6 length = 18 )
        ( segment_type = 'Z1ITEMTEXT' field_name = 'TDLINE' offset = 0 length = 70 )
        ( segment_type = 'Z1SCHEDULE' field_name = 'EDATU'  offset = 0 length = 8 ) ) ).
  ENDMETHOD.

ENDCLASS.


CLASS ltc_segment DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_item,
        posnr TYPE c LENGTH 6,
        matnr TYPE c LENGTH 18,
      END OF ty_item.
    TYPES:
      BEGIN OF ty_not_character_like,
        posnr    TYPE c LENGTH 6,
        quantity TYPE i,
      END OF ty_not_character_like.

    DATA idoc TYPE REF TO zcl_idoctor.
    DATA item TYPE REF TO zcl_idoctor_segment.

    METHODS setup RAISING cx_static_check.
    METHODS when_value_set_then_read_back FOR TESTING RAISING cx_static_check.
    METHODS given_long_value_then_raises FOR TESTING RAISING cx_static_check.
    METHODS given_unknown_field_raises FOR TESTING RAISING cx_static_check.
    METHODS when_data_set_then_fields_set FOR TESTING RAISING cx_static_check.
    METHODS when_data_read_then_typed FOR TESTING RAISING cx_static_check.
    METHODS given_numeric_data_raises FOR TESTING RAISING cx_static_check.
    METHODS given_other_ddic_type_raises FOR TESTING RAISING cx_static_check.
    METHODS when_child_added_then_linked FOR TESTING RAISING cx_static_check.
    METHODS given_wrong_parent_raises FOR TESTING RAISING cx_static_check.
    METHODS when_inserted_before_first FOR TESTING RAISING cx_static_check.
    METHODS given_bad_order_insert_raises FOR TESTING RAISING cx_static_check.
    METHODS when_removed_then_gone FOR TESTING RAISING cx_static_check.
    METHODS given_removed_add_raises FOR TESTING RAISING cx_static_check.
    METHODS when_found_below_then_own FOR TESTING RAISING cx_static_check.
    METHODS when_values_chained_then_set FOR TESTING RAISING cx_static_check.
    METHODS when_data_set_then_self FOR TESTING RAISING cx_static_check.
    METHODS when_added_then_renumbered FOR TESTING RAISING cx_static_check.
    METHODS given_removed_number_raises FOR TESTING RAISING cx_static_check.
    METHODS when_found_below_without_type FOR TESTING RAISING cx_static_check.
ENDCLASS.


CLASS ltc_segment IMPLEMENTATION.

  METHOD setup.
    idoc = zcl_idoctor=>create( lth_idoc=>syntax( ) ).
    item = idoc->add( 'Z1ITEM' ).
  ENDMETHOD.


  METHOD when_value_set_then_read_back.
    item->set_value( field = 'MATNR'
                     value = 'MAT-A' ).

    cl_abap_unit_assert=>assert_equals( act = item->get_value( 'MATNR' )
                                        exp = `MAT-A`
                                        msg = `A field must return what was written into it` ).
  ENDMETHOD.


  METHOD given_long_value_then_raises.
    TRY.
        item->set_value( field = 'POSNR'
                         value = '0000010' ).
        cl_abap_unit_assert=>fail( msg = `Seven characters must not fit into a six-character field` ).
      CATCH zcx_idoctor_error INTO DATA(error).
        cl_abap_unit_assert=>assert_equals( act = error->if_t100_message~t100key-msgno
                                            exp = '007'
                                            msg = `Wrong error - expected: value does not fit` ).
    ENDTRY.
  ENDMETHOD.


  METHOD given_unknown_field_raises.
    TRY.
        item->get_value( 'KUNNR' ).
        cl_abap_unit_assert=>fail( msg = `A field outside the segment definition must be rejected` ).
      CATCH zcx_idoctor_error INTO DATA(error).
        cl_abap_unit_assert=>assert_equals( act = error->if_t100_message~t100key-msgno
                                            exp = '006'
                                            msg = `Wrong error - expected: field not defined` ).
    ENDTRY.
  ENDMETHOD.


  METHOD when_data_set_then_fields_set.
    item->set_data( VALUE ty_item( posnr = '000010'
                                   matnr = 'MAT-A' ) ).

    cl_abap_unit_assert=>assert_equals( act = item->get_value( 'MATNR' )
                                        exp = `MAT-A`
                                        msg = `The typed write must land in the fields of the segment` ).
  ENDMETHOD.


  METHOD when_data_read_then_typed.
    DATA typed TYPE ty_item.
    item->set_value( field = 'POSNR'
                     value = '000020' ).

    item->get_data( IMPORTING data = typed ).

    cl_abap_unit_assert=>assert_equals( act = typed-posnr
                                        exp = '000020'
                                        msg = `The typed read must return the content of the field` ).
  ENDMETHOD.


  METHOD given_numeric_data_raises.
    TRY.
        item->set_data( VALUE ty_not_character_like( posnr = '000010' ) ).
        cl_abap_unit_assert=>fail( msg = `A structure with an integer must be rejected` ).
      CATCH zcx_idoctor_error INTO DATA(error).
        cl_abap_unit_assert=>assert_equals( act = error->if_t100_message~t100key-msgno
                                            exp = '008'
                                            msg = `Wrong error - expected: type does not fit` ).
    ENDTRY.
  ENDMETHOD.


  METHOD given_other_ddic_type_raises.
    " EDI_DC40 is a character-like DDIC structure - of the control record, not of segment Z1ITEM
    TRY.
        item->set_data( VALUE edi_dc40( ) ).
        cl_abap_unit_assert=>fail( msg = `The DDIC structure of another object must be rejected` ).
      CATCH zcx_idoctor_error INTO DATA(error).
        cl_abap_unit_assert=>assert_equals( act = error->if_t100_message~t100key-msgno
                                            exp = '009'
                                            msg = `Wrong error - expected: structure does not belong` ).
    ENDTRY.
  ENDMETHOD.


  METHOD when_child_added_then_linked.
    DATA(text) = item->add( 'Z1ITEMTEXT' ).

    DATA(texts) = item->children( 'Z1ITEMTEXT' ).
    cl_abap_unit_assert=>assert_equals( act = text->parent( )
                                        exp = item
                                        msg = `The new child must know its parent` ).
    cl_abap_unit_assert=>assert_equals( act = texts[ 1 ]
                                        exp = text
                                        msg = `The parent must list the new child` ).
  ENDMETHOD.


  METHOD given_wrong_parent_raises.
    TRY.
        item->add( 'Z1TOTAL' ).
        cl_abap_unit_assert=>fail( msg = `A top-level segment must not go under an item` ).
      CATCH zcx_idoctor_error INTO DATA(error).
        cl_abap_unit_assert=>assert_equals( act = error->if_t100_message~t100key-msgno
                                            exp = '003'
                                            msg = `Wrong error - expected: belongs under another parent` ).
    ENDTRY.
  ENDMETHOD.


  METHOD when_inserted_before_first.
    DATA(new_item) = item->insert_before( 'Z1ITEM' ).

    DATA(items) = idoc->segments( 'Z1ITEM' ).
    cl_abap_unit_assert=>assert_equals( act = items[ 1 ]
                                        exp = new_item
                                        msg = `The inserted item must come before the existing one` ).
  ENDMETHOD.


  METHOD given_bad_order_insert_raises.
    DATA(schedule) = item->add( 'Z1SCHEDULE' ).

    TRY.
        schedule->insert_after( 'Z1ITEMTEXT' ).
        cl_abap_unit_assert=>fail( msg = `A text behind the schedule line breaks the order of the syntax` ).
      CATCH zcx_idoctor_error INTO DATA(error).
        cl_abap_unit_assert=>assert_equals( act = error->if_t100_message~t100key-msgno
                                            exp = '005'
                                            msg = `Wrong error - expected: ordered differently` ).
    ENDTRY.
  ENDMETHOD.


  METHOD when_removed_then_gone.
    DATA(text) = item->add( 'Z1ITEMTEXT' ).

    text->remove( ).

    cl_abap_unit_assert=>assert_initial( act = item->children( )
                                         msg = `The removed child must no longer be listed` ).
    cl_abap_unit_assert=>assert_not_bound( act = text->parent( )
                                           msg = `The removed child must no longer have a parent` ).
  ENDMETHOD.


  METHOD given_removed_add_raises.
    item->remove( ).

    TRY.
        item->add( 'Z1ITEMTEXT' ).
        cl_abap_unit_assert=>fail( msg = `A removed segment must not take new children` ).
      CATCH zcx_idoctor_error INTO DATA(error).
        cl_abap_unit_assert=>assert_equals( act = error->if_t100_message~t100key-msgno
                                            exp = '011'
                                            msg = `Wrong error - expected: no longer part of the IDoc` ).
    ENDTRY.
  ENDMETHOD.


  METHOD when_found_below_then_own.
    DATA(other_item) = idoc->add( 'Z1ITEM' ).
    item->add( 'Z1ITEMTEXT' )->set_value( field = 'TDLINE'
                                          value = 'first' ).
    other_item->add( 'Z1ITEMTEXT' )->set_value( field = 'TDLINE'
                                                value = 'second' ).

    DATA(texts) = item->find_all( 'Z1ITEMTEXT' ).

    cl_abap_unit_assert=>assert_equals( act = lines( texts )
                                        exp = 1
                                        msg = `find_all( ) of a segment must search only below it` ).
    cl_abap_unit_assert=>assert_equals( act = texts[ 1 ]->get_value( 'TDLINE' )
                                        exp = `first`
                                        msg = `The text found must be the one of this item` ).
  ENDMETHOD.


  METHOD when_values_chained_then_set.
    item->set_value( field = 'POSNR'
                     value = '000010'
      )->set_value( field = 'MATNR'
                    value = 'MAT-A' ).

    cl_abap_unit_assert=>assert_equals( act = |{ item->get_value( 'POSNR' ) } { item->get_value( 'MATNR' ) }|
                                        exp = `000010 MAT-A`
                                        msg = `Each call of a chain must write its field` ).
  ENDMETHOD.


  METHOD when_data_set_then_self.
    DATA(returned) = item->set_data( VALUE ty_item( posnr = '000010' ) ).

    cl_abap_unit_assert=>assert_equals( act = returned
                                        exp = item
                                        msg = `set_data( ) must return the segment itself` ).
  ENDMETHOD.


  METHOD when_added_then_renumbered.
    DATA(text) = item->add( 'Z1ITEMTEXT' ).
    cl_abap_unit_assert=>assert_equals( act = text->number( )
                                        exp = '000002'
                                        msg = `The first child of the first segment must be number 2` ).

    " the head goes in front of the item, so everything behind it moves up by one
    idoc->add( 'Z1HEAD' ).

    cl_abap_unit_assert=>assert_equals( act = text->number( )
                                        exp = '000003'
                                        msg = `A segment added in front must renumber the text` ).
  ENDMETHOD.


  METHOD given_removed_number_raises.
    item->remove( ).

    TRY.
        item->number( ).
        cl_abap_unit_assert=>fail( msg = `A removed segment must have no number` ).
      CATCH zcx_idoctor_error INTO DATA(error).
        cl_abap_unit_assert=>assert_equals( act = error->if_t100_message~t100key-msgno
                                            exp = '011'
                                            msg = `Wrong error - expected: no longer part of the IDoc` ).
    ENDTRY.
  ENDMETHOD.


  METHOD when_found_below_without_type.
    DATA(text) = item->add( 'Z1ITEMTEXT' ).
    DATA(schedule) = item->add( 'Z1SCHEDULE' ).
    idoc->add( 'Z1ITEM' )->add( 'Z1ITEMTEXT' ).

    DATA(below) = item->find_all( ).

    cl_abap_unit_assert=>assert_equals( act = below
                                        exp = VALUE zcl_idoctor=>ty_segments( ( text ) ( schedule ) )
                                        msg = `find_all( ) without a type must list everything below, nothing else` ).
  ENDMETHOD.

ENDCLASS.
