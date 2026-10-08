"! The repository against doubles of every function module it calls (Function Module Test
"! Double Framework, ABAP 7.56 and later) - no test reads or writes an IDoc. The segment types
"! are the standard ORDERS05 segments, so that their DDIC structures give the field layout.
CLASS ltc_repository DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    TYPES ty_segment_rows TYPE STANDARD TABLE OF edi_iapi11 WITH EMPTY KEY.

    CONSTANTS docnum TYPE edidc-docnum VALUE '0000000000004711'.
    CONSTANTS idoc_type TYPE edidc-idoctp VALUE 'ORDERS05'.

    CLASS-DATA function_modules TYPE REF TO if_function_test_environment.
    DATA cut TYPE REF TO zif_idoctor_repository.

    CLASS-METHODS class_setup.
    METHODS setup.

    METHODS when_loaded_then_tree FOR TESTING RAISING cx_static_check.
    METHODS when_field_read_then_ddic_pos FOR TESTING RAISING cx_static_check.
    METHODS given_no_idoc_load_raises FOR TESTING RAISING cx_static_check.
    METHODS when_read_then_group_counts FOR TESTING RAISING cx_static_check.
    METHODS when_read_then_optional_min_0 FOR TESTING RAISING cx_static_check.
    METHODS when_read_twice_then_one_call FOR TESTING RAISING cx_static_check.
    METHODS given_unknown_type_raises FOR TESTING RAISING cx_static_check.
    METHODS when_saved_then_change_written FOR TESTING RAISING cx_static_check.
    METHODS when_saved_then_no_commit FOR TESTING RAISING cx_static_check.
    METHODS given_commit_then_committed FOR TESTING RAISING cx_static_check.
    METHODS given_no_change_no_write FOR TESTING RAISING cx_static_check.
    METHODS given_new_segment_save_raises FOR TESTING RAISING cx_static_check.
    METHODS given_db_change_save_raises FOR TESTING RAISING cx_static_check.
    METHODS given_locked_idoc_save_raises FOR TESTING RAISING cx_static_check.
    METHODS given_no_number_save_raises FOR TESTING RAISING cx_static_check.

    METHODS loaded_idoc
      RETURNING VALUE(result) TYPE REF TO zcl_idoctor
      RAISING   zcx_idoctor_error.

    METHODS second_item
      IMPORTING idoc          TYPE REF TO zcl_idoctor
      RETURNING VALUE(result) TYPE REF TO zcl_idoctor_segment
      RAISING   zcx_idoctor_error.

    METHODS configure_idoc.
    METHODS configure_syntax.

    METHODS configure_edit
      IMPORTING control TYPE edidc.

    METHODS verify_close
      IMPORTING update TYPE abap_bool
                commit TYPE abap_bool.

    METHODS stored_control
      RETURNING VALUE(result) TYPE edidc.

    METHODS stored_records
      RETURNING VALUE(result) TYPE zcl_idoctor=>ty_data_records.

    METHODS segment_rows
      RETURNING VALUE(result) TYPE ty_segment_rows.
ENDCLASS.


CLASS ltc_repository IMPLEMENTATION.

  METHOD class_setup.
    " every function module the repository calls is doubled - that is what keeps the tests HARMLESS
    function_modules = cl_function_test_environment=>create( VALUE #( ( 'IDOC_READ_COMPLETELY' )
                                                                      ( 'IDOCTYPE_READ_COMPLETE' )
                                                                      ( 'EDI_DOCUMENT_OPEN_FOR_EDIT' )
                                                                      ( 'EDI_CHANGE_DATA_SEGMENTS' )
                                                                      ( 'EDI_DOCUMENT_CLOSE_EDIT' ) ) ).
  ENDMETHOD.


  METHOD setup.
    function_modules->clear_doubles( ).
    cut = NEW zcl_idoctor_repository( ).
  ENDMETHOD.


  METHOD when_loaded_then_tree.
    DATA(idoc) = loaded_idoc( ).

    DATA(material) = idoc->find_first( 'E1EDP19' ).

    cl_abap_unit_assert=>assert_equals( act = material->parent( )->get_value( 'POSEX' )
                                        exp = `000010`
                                        msg = `The material must hang under the item stored before it` ).
  ENDMETHOD.


  METHOD when_field_read_then_ddic_pos.
    DATA(idoc) = loaded_idoc( ).

    DATA(header) = idoc->find_first( 'E1EDK01' ).

    cl_abap_unit_assert=>assert_equals( act = header->get_value( 'CURCY' )
                                        exp = `EUR`
                                        msg = `Fields must sit where the DDIC structure of the segment puts them` ).
  ENDMETHOD.


  METHOD given_no_idoc_load_raises.
    " verify in ADT: name and form of the parameter of then_raise_classic_exception( )
    function_modules->get_double( 'IDOC_READ_COMPLETELY' )->configure_call(
      )->ignore_all_parameters(
      )->then_raise_classic_exception( 'DOCUMENT_NOT_EXIST' ).

    TRY.
        cut->load( docnum ).
        cl_abap_unit_assert=>fail( msg = `A missing IDoc must raise` ).
      CATCH zcx_idoctor_error INTO DATA(error).
        cl_abap_unit_assert=>assert_equals( act = error->if_t100_message~t100key-msgno
                                            exp = '030'
                                            msg = `Wrong error - expected: IDoc does not exist` ).
    ENDTRY.
  ENDMETHOD.


  METHOD when_read_then_group_counts.
    configure_syntax( ).

    DATA(syntax) = cut->read_syntax( idoc_type ).

    DATA(item) = syntax-segments[ segment_type = 'E1EDP01' ].
    cl_abap_unit_assert=>assert_equals( act = item-max_occurrence
                                        exp = 999999
                                        msg = `The first segment of a group must take the group's maximum` ).
    cl_abap_unit_assert=>assert_equals( act = item-min_occurrence
                                        exp = 1
                                        msg = `A mandatory group must occur at least once` ).
  ENDMETHOD.


  METHOD when_read_then_optional_min_0.
    configure_syntax( ).

    DATA(syntax) = cut->read_syntax( idoc_type ).

    DATA(material) = syntax-segments[ segment_type = 'E1EDP19' ].
    cl_abap_unit_assert=>assert_equals( act = material-min_occurrence
                                        exp = 0
                                        msg = `An optional segment must have no lower bound, whatever OCCMIN says` ).
  ENDMETHOD.


  METHOD when_read_twice_then_one_call.
    configure_syntax( ).

    cut->read_syntax( idoc_type ).
    cut->read_syntax( idoc_type ).

    function_modules->get_double( 'IDOCTYPE_READ_COMPLETE' )->verify( )->is_called_once( ).
  ENDMETHOD.


  METHOD given_unknown_type_raises.
    function_modules->get_double( 'IDOCTYPE_READ_COMPLETE' )->configure_call(
      )->ignore_all_parameters(
      )->then_raise_classic_exception( 'OBJECT_UNKNOWN' ).

    TRY.
        cut->read_syntax( idoc_type ).
        cl_abap_unit_assert=>fail( msg = `An unknown IDoc type must raise` ).
      CATCH zcx_idoctor_error INTO DATA(error).
        cl_abap_unit_assert=>assert_equals( act = error->if_t100_message~t100key-msgno
                                            exp = '032'
                                            msg = `Wrong error - expected: IDoc type does not exist` ).
    ENDTRY.
  ENDMETHOD.


  METHOD when_saved_then_change_written.
    DATA item TYPE e1edp01.
    DATA(idoc) = loaded_idoc( ).
    configure_edit( stored_control( ) ).
    second_item( idoc )->set_value( field = 'MENEE'
                                    value = 'KGM' ).

    cut->save( idoc ).

    " only the changed record is handed over, with the numbers it has in the database
    DATA(records) = stored_records( ).
    DATA(expected_record) = records[ 4 ].
    item = expected_record-sdata.
    item-menee = 'KGM'.
    expected_record-sdata = item.
    DATA(change) = function_modules->get_double( 'EDI_CHANGE_DATA_SEGMENTS' ).
    DATA(expected_change) = change->create_input_configuration(
      )->set_table_parameter( name  = 'IDOC_CHANGED_DATA_RANGE'
                              value = VALUE zcl_idoctor=>ty_data_records( ( expected_record ) ) ).
    " verify in ADT: verify( ) with an input configuration compares the configured parameters
    change->verify( expected_change )->is_called_once( ).
  ENDMETHOD.


  METHOD when_saved_then_no_commit.
    DATA(idoc) = loaded_idoc( ).
    configure_edit( stored_control( ) ).
    second_item( idoc )->set_value( field = 'MENEE'
                                    value = 'KGM' ).

    cut->save( idoc ).

    verify_close( update = abap_true
                  commit = abap_false ).
  ENDMETHOD.


  METHOD given_commit_then_committed.
    DATA(idoc) = loaded_idoc( ).
    configure_edit( stored_control( ) ).
    second_item( idoc )->set_value( field = 'MENEE'
                                    value = 'KGM' ).

    cut->save( idoc     = idoc
               settings = VALUE #( commit = abap_true ) ).

    verify_close( update = abap_true
                  commit = abap_true ).
  ENDMETHOD.


  METHOD given_no_change_no_write.
    DATA(idoc) = loaded_idoc( ).
    configure_edit( stored_control( ) ).

    cut->save( idoc ).

    function_modules->get_double( 'EDI_CHANGE_DATA_SEGMENTS' )->verify( )->is_never_called( ).
    verify_close( update = abap_false
                  commit = abap_false ).
  ENDMETHOD.


  METHOD given_new_segment_save_raises.
    DATA(idoc) = loaded_idoc( ).
    configure_edit( stored_control( ) ).
    second_item( idoc )->add( 'E1EDP19' ).

    TRY.
        cut->save( idoc ).
        cl_abap_unit_assert=>fail( msg = `A segment that is not in the database must not be saved` ).
      CATCH zcx_idoctor_error INTO DATA(error).
        cl_abap_unit_assert=>assert_equals( act = error->if_t100_message~t100key-msgno
                                            exp = '038'
                                            msg = `Wrong error - expected: only contents can be saved` ).
    ENDTRY.

    function_modules->get_double( 'EDI_CHANGE_DATA_SEGMENTS' )->verify( )->is_never_called( ).
    " the IDoc opened for the save is closed again without update
    verify_close( update = abap_false
                  commit = abap_false ).
  ENDMETHOD.


  METHOD given_db_change_save_raises.
    DATA(idoc) = loaded_idoc( ).
    DATA(changed_control) = stored_control( ).
    changed_control-updtim = '120501'.
    configure_edit( changed_control ).
    second_item( idoc )->set_value( field = 'MENEE'
                                    value = 'KGM' ).

    TRY.
        cut->save( idoc ).
        cl_abap_unit_assert=>fail( msg = `An IDoc changed in the database since loading must not be saved` ).
      CATCH zcx_idoctor_error INTO DATA(error).
        cl_abap_unit_assert=>assert_equals( act = error->if_t100_message~t100key-msgno
                                            exp = '050'
                                            msg = `Wrong error - expected: changed after it was loaded` ).
    ENDTRY.

    function_modules->get_double( 'EDI_CHANGE_DATA_SEGMENTS' )->verify( )->is_never_called( ).
    verify_close( update = abap_false
                  commit = abap_false ).
  ENDMETHOD.


  METHOD given_locked_idoc_save_raises.
    DATA(idoc) = loaded_idoc( ).
    function_modules->get_double( 'EDI_DOCUMENT_OPEN_FOR_EDIT' )->configure_call(
      )->ignore_all_parameters(
      )->then_raise_classic_exception( 'DOCUMENT_FOREIGN_LOCK' ).

    TRY.
        cut->save( idoc ).
        cl_abap_unit_assert=>fail( msg = `A locked IDoc must not be saved` ).
      CATCH zcx_idoctor_error INTO DATA(error).
        cl_abap_unit_assert=>assert_equals( act = error->if_t100_message~t100key-msgno
                                            exp = '035'
                                            msg = `Wrong error - expected: locked by another user` ).
    ENDTRY.

    function_modules->get_double( 'EDI_DOCUMENT_CLOSE_EDIT' )->verify( )->is_never_called( ).
  ENDMETHOD.


  METHOD given_no_number_save_raises.
    configure_syntax( ).
    DATA(idoc) = zcl_idoctor=>create( cut->read_syntax( idoc_type ) ).

    TRY.
        cut->save( idoc ).
        cl_abap_unit_assert=>fail( msg = `An IDoc that was never stored must not be saved` ).
      CATCH zcx_idoctor_error INTO DATA(error).
        cl_abap_unit_assert=>assert_equals( act = error->if_t100_message~t100key-msgno
                                            exp = '039'
                                            msg = `Wrong error - expected: the IDoc has no number` ).
    ENDTRY.

    function_modules->get_double( 'EDI_DOCUMENT_OPEN_FOR_EDIT' )->verify( )->is_never_called( ).
  ENDMETHOD.


  METHOD loaded_idoc.
    configure_idoc( ).
    configure_syntax( ).
    result = cut->load( docnum ).
  ENDMETHOD.


  METHOD second_item.
    result = idoc->find_first( name  = 'E1EDP01'
                               field = 'POSEX'
                               value = '000020' ).
  ENDMETHOD.


  METHOD configure_idoc.
    DATA(double) = function_modules->get_double( 'IDOC_READ_COMPLETELY' ).
    DATA(output) = double->create_output_configuration(
      )->set_exporting_parameter( name  = 'IDOC_CONTROL'
                                  value = stored_control( )
      )->set_table_parameter( name  = 'INT_EDIDD'
                              value = stored_records( ) ).
    double->configure_call( )->ignore_all_parameters( )->then_set_output( output ).
  ENDMETHOD.


  METHOD configure_syntax.
    DATA(double) = function_modules->get_double( 'IDOCTYPE_READ_COMPLETE' ).
    DATA(output) = double->create_output_configuration(
      )->set_table_parameter( name  = 'PT_SEGMENTS'
                              value = segment_rows( ) ).
    double->configure_call( )->ignore_all_parameters( )->then_set_output( output ).
  ENDMETHOD.


  METHOD configure_edit.
    DATA(double) = function_modules->get_double( 'EDI_DOCUMENT_OPEN_FOR_EDIT' ).
    DATA(output) = double->create_output_configuration(
      )->set_exporting_parameter( name  = 'IDOC_CONTROL'
                                  value = control
      )->set_table_parameter( name  = 'IDOC_DATA'
                              value = stored_records( ) ).
    double->configure_call( )->ignore_all_parameters( )->then_set_output( output ).
  ENDMETHOD.


  METHOD verify_close.
    DATA(close) = function_modules->get_double( 'EDI_DOCUMENT_CLOSE_EDIT' ).
    DATA(expected_close) = close->create_input_configuration(
      )->set_importing_parameter( name  = 'DOCUMENT_NUMBER'
                                  value = docnum
      )->set_importing_parameter( name  = 'DO_UPDATE'
                                  value = update
      )->set_importing_parameter( name  = 'DO_COMMIT'
                                  value = commit ).
    " verify in ADT: verify( ) with an input configuration compares the configured parameters
    close->verify( expected_close )->is_called_once( ).
  ENDMETHOD.


  METHOD stored_control.
    result = VALUE #( docnum = docnum
                      idoctp = idoc_type
                      upddat = '20261001'
                      updtim = '120000' ).
  ENDMETHOD.


  METHOD stored_records.
    DATA header TYPE e1edk01.
    DATA first_item TYPE e1edp01.
    DATA material TYPE e1edp19.
    DATA other_item TYPE e1edp01.

    header-curcy = 'EUR'.
    first_item-posex = '000010'.
    first_item-menee = 'PCE'.
    material-qualf = '002'.
    material-idtnr = 'MAT-A'.
    other_item-posex = '000020'.
    other_item-menee = 'PCE'.
    result = VALUE #( docnum = docnum
                      ( segnum = '000001' segnam = 'E1EDK01' hlevel = '02' sdata = header )
                      ( segnum = '000002' segnam = 'E1EDP01' hlevel = '02' sdata = first_item )
                      ( segnum = '000003' segnam = 'E1EDP19' hlevel = '03' sdata = material psgnum = '000002' )
                      ( segnum = '000004' segnam = 'E1EDP01' hlevel = '02' sdata = other_item ) ).
  ENDMETHOD.


  METHOD segment_rows.
    " E1EDP01 starts a group: the segment itself 1..1 per group, the group 1..999999;
    " E1EDP19 is optional although its OCCMIN says 1, as SAP stores it
    result = VALUE #( ( nr = '0001' segmenttyp = 'E1EDK01' hlevel = '02' mustfl = abap_true
                        occmin = '1' occmax = '1' )
                      ( nr = '0002' segmenttyp = 'E1EDP01' hlevel = '02' mustfl = abap_true
                        occmin = '1' occmax = '1' parflg = abap_true
                        grp_mustfl = abap_true grp_occmin = '1' grp_occmax = '999999' )
                      ( nr = '0003' segmenttyp = 'E1EDP19' hlevel = '03' parseg = 'E1EDP01' parpno = '0002'
                        occmin = '1' occmax = '99' ) ).
  ENDMETHOD.

ENDCLASS.
