"! An IDoc as an object tree - the aggregate root of IDoctor. It holds the syntax of the IDoc
"! type, the control record and the top-level segments, and it owns every structural rule:
"! which parent a segment needs, where it goes among its siblings, how often it may occur and
"! whether it must occur. Segments are created, inserted and removed only here, so
"! zcl_idoctor_segment hands every structural change to its IDoc. Pure in-memory - reading and
"! saving IDocs is the job of zif_idoctor_repository.
CLASS zcl_idoctor DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE
  GLOBAL FRIENDS zcl_idoctor_segment.

  PUBLIC SECTION.
    "! Segment type, e.g. E1EDK01
    TYPES ty_segment_type TYPE edidd-segnam.
    "! Field of a segment type, e.g. CURCY
    TYPES ty_field_name TYPE fieldname.
    TYPES:
      "! A segment type of the IDoc type, as its syntax defines it
      BEGIN OF ty_segment_definition,
        "! Segment type, e.g. E1EDP01
        segment_type    TYPE ty_segment_type,
        "! Segment definition (version) whose layout SDATA has, e.g. E2EDP01011; may be initial
        definition      TYPE ty_segment_type,
        "! Segment type of the parent; initial for a top-level segment
        parent_type     TYPE ty_segment_type,
        "! Sequence within the IDoc type - siblings appear in ascending position
        position        TYPE i,
        "! Hierarchy level, written to EDIDD-HLEVEL
        hierarchy_level TYPE edidd-hlevel,
        "! Least number of occurrences under one parent; 0 when the segment is optional
        min_occurrence  TYPE int8,
        "! Greatest number of occurrences under one parent
        max_occurrence  TYPE int8,
      END OF ty_segment_definition.
    "! Segment types by segment type; key BY_PARENT lists them by parent and position
    TYPES ty_segment_definitions TYPE SORTED TABLE OF ty_segment_definition
      WITH UNIQUE KEY segment_type
      WITH NON-UNIQUE SORTED KEY by_parent COMPONENTS parent_type position.
    TYPES:
      "! Place of a field in the segment data (EDIDD-SDATA)
      BEGIN OF ty_field_definition,
        segment_type TYPE ty_segment_type,
        field_name   TYPE ty_field_name,
        "! Offset in characters from the start of SDATA
        offset       TYPE i,
        "! Length in characters
        length       TYPE i,
      END OF ty_field_definition.
    "! Fields by segment type and field name
    TYPES ty_field_definitions TYPE SORTED TABLE OF ty_field_definition
      WITH UNIQUE KEY segment_type field_name.
    TYPES:
      "! Syntax of an IDoc type - basic type plus optional extension
      BEGIN OF ty_syntax,
        idoc_type TYPE edidc-idoctp,
        extension TYPE edidc-cimtyp,
        segments  TYPE ty_segment_definitions,
        fields    TYPE ty_field_definitions,
      END OF ty_syntax.
    "! Segments in document order
    TYPES ty_segments TYPE STANDARD TABLE OF REF TO zcl_idoctor_segment WITH EMPTY KEY.
    "! Data records in document order
    TYPES ty_data_records TYPE STANDARD TABLE OF edidd WITH EMPTY KEY.
    TYPES:
      "! A deviation from the syntax, as validate( ) reports it
      BEGIN OF ty_finding,
        "! Segment concerned; for a missing segment its parent, not bound on IDoc level
        segment TYPE REF TO zcl_idoctor_segment,
        "! Message class of the text - ZIDOCTOR
        msgid   TYPE symsgid,
        msgno   TYPE symsgno,
        msgv1   TYPE symsgv,
        msgv2   TYPE symsgv,
        msgv3   TYPE symsgv,
        msgv4   TYPE symsgv,
        "! Message text in the logon language
        text    TYPE string,
      END OF ty_finding.
    "! Findings of validate( )
    TYPES ty_findings TYPE STANDARD TABLE OF ty_finding WITH EMPTY KEY.

    "! Use create( ) or from_edidd( ); the constructor is public only because global classes
    "! require it.
    "!
    "! @parameter syntax  | Syntax of the IDoc type
    "! @parameter control | Control record; IDoc type and extension are taken from the syntax
    METHODS constructor
      IMPORTING syntax  TYPE ty_syntax
                control TYPE edidc.

    "! Creates an IDoc without segments, e.g. to build EDIDD records from scratch.
    "!
    "! @parameter syntax | Syntax of the IDoc type, e.g. from zif_idoctor_repository~read_syntax( )
    "! @parameter result | Empty IDoc; its control record carries IDoc type and extension
    "! @raising zcx_idoctor_error | The syntax contains no segments
    CLASS-METHODS create
      IMPORTING syntax        TYPE ty_syntax
      RETURNING VALUE(result) TYPE REF TO zcl_idoctor
      RAISING   zcx_idoctor_error.

    "! Builds the tree from data records - e.g. the EDIDD table of a user exit or BAdI. The
    "! parent of each segment is derived from the syntax, so SEGNUM, PSGNUM and HLEVEL need not
    "! be filled. Records that break cardinality or order are accepted; validate( ) reports them.
    "!
    "! @parameter syntax  | Syntax of the IDoc type
    "! @parameter data    | Standard table with line type EDIDD, in document order
    "! @parameter control | Control record; when its IDoc type is filled it must match the syntax
    "! @parameter result  | The IDoc
    "! @raising zcx_idoctor_error | The syntax is empty, the table is no EDIDD table, a segment type
    "!                             is not in the syntax, a segment has no parent before it, or the
    "!                             control record belongs to another IDoc type
    CLASS-METHODS from_edidd
      IMPORTING syntax        TYPE ty_syntax
                data          TYPE STANDARD TABLE
                control       TYPE edidc OPTIONAL
      RETURNING VALUE(result) TYPE REF TO zcl_idoctor
      RAISING   zcx_idoctor_error.

    "! Data records in document order, numbered afresh: SEGNUM counts from 000001, PSGNUM holds
    "! the SEGNUM of the parent (000000 on top level), HLEVEL comes from the syntax. MANDT and
    "! DOCNUM are taken from the control record.
    "!
    "! @parameter result | Data records, e.g. for the EDIDD table of a user exit
    METHODS to_edidd
      RETURNING VALUE(result) TYPE ty_data_records.

    "! The IDoc as a flat file, the way a file port writes it: the control record as EDI_DC40,
    "! then one EDI_DD40 data record per segment in document order, numbered as in to_edidd( ).
    "! Every record is padded to its full length and followed by the line break. Data records
    "! carry the segment definition (e.g. E2EDK01005) where the syntax knows it, otherwise the
    "! segment type.
    "!
    "! @parameter line_break | Text after each record; LF when not supplied, empty for one
    "!                        continuous block of fixed-length records
    "! @parameter result     | File content
    METHODS to_flat_file
      IMPORTING line_break    TYPE string OPTIONAL
      RETURNING VALUE(result) TYPE string.

    "! The IDoc as IDoc-XML, the way an XML port writes it: a root element named after the
    "! extension (the basic type when there is none) holding one IDOC element with the control
    "! record as EDI_DC40 and one element per segment, children nested in their parent. Fields
    "! with initial content are left out. A slash in a name becomes _- as SAP writes it.
    "!
    "! @parameter result | XML document, indented by two blanks per level, lines ended by LF
    METHODS to_xml
      RETURNING VALUE(result) TYPE string.

    "! @parameter result | Control record - for a loaded IDoc as read from the database
    METHODS control
      RETURNING VALUE(result) TYPE edidc.

    "! Top-level segments.
    "!
    "! @parameter name   | Only segments of this type; all top-level segments when initial
    "! @parameter result | Segments in document order
    METHODS segments
      IMPORTING name          TYPE ty_segment_type OPTIONAL
      RETURNING VALUE(result) TYPE ty_segments.

    "! First segment of the IDoc with the given type and, when a field is given, field value.
    "!
    "! @parameter name   | Segment type
    "! @parameter field  | Field to compare; when initial, every segment of the type matches
    "! @parameter value  | Content the field must have; compared without trailing blanks
    "! @parameter result | First match in document order
    "! @raising zcx_idoctor_error | The segment type or field is not defined, or no segment matches
    METHODS find_first
      IMPORTING name          TYPE ty_segment_type
                field         TYPE ty_field_name OPTIONAL
                value         TYPE clike OPTIONAL
      RETURNING VALUE(result) TYPE REF TO zcl_idoctor_segment
      RAISING   zcx_idoctor_error.

    "! All segments of the IDoc with the given type and, when a field is given, field value -
    "! without a type, every segment of the IDoc.
    "!
    "! @parameter name   | Segment type; when initial, every segment matches
    "! @parameter field  | Field to compare, only together with a segment type; when initial,
    "!                    every segment of the type matches
    "! @parameter value  | Content the field must have; compared without trailing blanks
    "! @parameter result | Matches in document order; empty when there is none
    "! @raising zcx_idoctor_error | The segment type or field is not defined, or a field is given
    "!                             without a segment type
    METHODS find_all
      IMPORTING name          TYPE ty_segment_type OPTIONAL
                field         TYPE ty_field_name OPTIONAL
                value         TYPE clike OPTIONAL
      PREFERRED PARAMETER name
      RETURNING VALUE(result) TYPE ty_segments
      RAISING   zcx_idoctor_error.

    "! Segment by its number, as to_edidd( ) numbers it now. SAP numbers the segments of an IDoc
    "! from 000001 in document order, so for a loaded IDoc whose segments were not added, removed
    "! or moved this is the SEGNUM in the database - e.g. the number a status record
    "! (EDIDS-SEGNUM) gives for the segment an application error refers to.
    "!
    "! @parameter number | Segment number, e.g. 000017 or 17
    "! @parameter result | The segment
    "! @raising zcx_idoctor_error | No segment has that number
    METHODS find_by_number
      IMPORTING number        TYPE clike
      RETURNING VALUE(result) TYPE REF TO zcl_idoctor_segment
      RAISING   zcx_idoctor_error.

    "! Adds a top-level segment where the syntax puts it: after the segments of its own type,
    "! before the segment types that follow it in the IDoc type.
    "!
    "! @parameter name   | Segment type
    "! @parameter result | The new, empty segment
    "! @raising zcx_idoctor_error | The type is not defined, is no top-level type, or already
    "!                             occurs as often as the syntax allows
    METHODS add
      IMPORTING name          TYPE ty_segment_type
      RETURNING VALUE(result) TYPE REF TO zcl_idoctor_segment
      RAISING   zcx_idoctor_error.

    "! Checks the tree against the syntax: the least and greatest number of occurrences of every
    "! segment type under each parent - mandatory segments included - and the order of siblings.
    "!
    "! @parameter result | Findings; empty when the IDoc matches its syntax
    METHODS validate
      RETURNING VALUE(result) TYPE ty_findings.

  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_query,
        segment_type TYPE ty_segment_type,
        field        TYPE ty_field_definition,
        value        TYPE string,
      END OF ty_query.
    TYPES:
      BEGIN OF ty_number,
        segment TYPE REF TO zcl_idoctor_segment,
        number  TYPE edidd-segnum,
      END OF ty_number.
    TYPES ty_numbers TYPE HASHED TABLE OF ty_number WITH UNIQUE KEY segment.
    TYPES ty_field_definitions_by_offset TYPE SORTED TABLE OF ty_field_definition
      WITH NON-UNIQUE KEY offset.

    " length of EDIDD-SDATA in characters
    CONSTANTS max_data_length TYPE i VALUE 1000.
    " what TABNAM of a control record says in files and XML
    CONSTANTS control_record_name TYPE edi_dc40-tabnam VALUE 'EDI_DC40'.
    " blanks per level of indentation in to_xml( )
    CONSTANTS xml_indentation TYPE i VALUE 2.

    DATA syntax TYPE ty_syntax.
    DATA control_record TYPE edidc.
    DATA top_segments TYPE ty_segments.

    CLASS-METHODS check_syntax
      IMPORTING syntax TYPE ty_syntax
      RAISING   zcx_idoctor_error.

    CLASS-METHODS check_control
      IMPORTING syntax  TYPE ty_syntax
                control TYPE edidc
      RAISING   zcx_idoctor_error.

    CLASS-METHODS check_edidd_table
      IMPORTING data TYPE STANDARD TABLE
      RAISING   zcx_idoctor_error.

    CLASS-METHODS of_type
      IMPORTING segments      TYPE ty_segments
                name          TYPE ty_segment_type
      RETURNING VALUE(result) TYPE ty_segments.

    CLASS-METHODS is_character_like
      IMPORTING descriptor    TYPE REF TO cl_abap_typedescr
      RETURNING VALUE(result) TYPE abap_bool.

    CLASS-METHODS are_components_character_like
      IMPORTING structure     TYPE REF TO cl_abap_structdescr
      RETURNING VALUE(result) TYPE abap_bool.

    CLASS-METHODS finding
      IMPORTING segment       TYPE REF TO zcl_idoctor_segment
                text          TYPE string
      RETURNING VALUE(result) TYPE ty_finding.

    CLASS-METHODS fits_at
      IMPORTING siblings      TYPE ty_segments
                target_index  TYPE i
                definition    TYPE ty_segment_definition
      RETURNING VALUE(result) TYPE abap_bool.

    METHODS build
      IMPORTING data TYPE STANDARD TABLE
      RAISING   zcx_idoctor_error.

    METHODS pop_to_parent
      IMPORTING parent_type TYPE ty_segment_type
      CHANGING  path        TYPE ty_segments.

    METHODS definition_of
      IMPORTING name          TYPE ty_segment_type
      RETURNING VALUE(result) TYPE ty_segment_definition
      RAISING   zcx_idoctor_error.

    METHODS field_definition
      IMPORTING segment_type  TYPE ty_segment_type
                field_name    TYPE ty_field_name
      RETURNING VALUE(result) TYPE ty_field_definition
      RAISING   zcx_idoctor_error.

    METHODS query_for
      IMPORTING name          TYPE ty_segment_type
                field         TYPE ty_field_name
                value         TYPE clike
      RETURNING VALUE(result) TYPE ty_query
      RAISING   zcx_idoctor_error.

    METHODS find_in
      IMPORTING segments      TYPE ty_segments
                query         TYPE ty_query
      RETURNING VALUE(result) TYPE ty_segments.

    METHODS find_first_in
      IMPORTING segments      TYPE ty_segments
                query         TYPE ty_query
      RETURNING VALUE(result) TYPE REF TO zcl_idoctor_segment
      RAISING   zcx_idoctor_error.

    METHODS add_child
      IMPORTING parent        TYPE REF TO zcl_idoctor_segment OPTIONAL
                name          TYPE ty_segment_type
      RETURNING VALUE(result) TYPE REF TO zcl_idoctor_segment
      RAISING   zcx_idoctor_error.

    " insert_next_to, remove_segment, number_of and check_data_type are called by
    " zcl_idoctor_segment, which hands its structural changes, numbering and type checks to the IDoc
    METHODS insert_next_to
      IMPORTING anchor        TYPE REF TO zcl_idoctor_segment
                name          TYPE ty_segment_type
                after         TYPE abap_bool
      RETURNING VALUE(result) TYPE REF TO zcl_idoctor_segment
      RAISING   zcx_idoctor_error ##CALLED.

    METHODS remove_segment
      IMPORTING segment TYPE REF TO zcl_idoctor_segment
      RAISING   zcx_idoctor_error ##CALLED.

    METHODS number_of
      IMPORTING segment       TYPE REF TO zcl_idoctor_segment
      RETURNING VALUE(result) TYPE edidd-segnum
      RAISING   zcx_idoctor_error ##CALLED.

    METHODS check_parent
      IMPORTING parent     TYPE REF TO zcl_idoctor_segment
                definition TYPE ty_segment_definition
      RAISING   zcx_idoctor_error.

    METHODS check_room
      IMPORTING parent     TYPE REF TO zcl_idoctor_segment
                definition TYPE ty_segment_definition
      RAISING   zcx_idoctor_error.

    METHODS check_attached
      IMPORTING segment TYPE REF TO zcl_idoctor_segment
      RAISING   zcx_idoctor_error.

    METHODS is_attached
      IMPORTING segment       TYPE REF TO zcl_idoctor_segment
      RETURNING VALUE(result) TYPE abap_bool.

    METHODS check_data_type
      IMPORTING data       TYPE any
                definition TYPE ty_segment_definition
      RAISING   zcx_idoctor_error ##CALLED.

    METHODS children_of
      IMPORTING parent        TYPE REF TO zcl_idoctor_segment
      RETURNING VALUE(result) TYPE REF TO ty_segments.

    METHODS new_segment
      IMPORTING definition    TYPE ty_segment_definition
                parent        TYPE REF TO zcl_idoctor_segment
      RETURNING VALUE(result) TYPE REF TO zcl_idoctor_segment.

    METHODS label_of
      IMPORTING parent        TYPE REF TO zcl_idoctor_segment
                numbers       TYPE ty_numbers OPTIONAL
      RETURNING VALUE(result) TYPE string.

    CLASS-METHODS fixed_width
      IMPORTING record        TYPE any
      RETURNING VALUE(result) TYPE string.

    CLASS-METHODS xml_name
      IMPORTING name          TYPE csequence
      RETURNING VALUE(result) TYPE string.

    CLASS-METHODS xml_element
      IMPORTING name          TYPE csequence
                value         TYPE csequence
                level         TYPE i
      RETURNING VALUE(result) TYPE string.

    CLASS-METHODS indentation
      IMPORTING level         TYPE i
      RETURNING VALUE(result) TYPE string.

    METHODS flat_control
      RETURNING VALUE(result) TYPE edi_dc40.

    METHODS flat_segment_name
      IMPORTING segment_type  TYPE ty_segment_type
      RETURNING VALUE(result) TYPE edi_dd40-segnam.

    METHODS control_xml
      IMPORTING level         TYPE i
      RETURNING VALUE(result) TYPE string.

    METHODS segments_xml
      IMPORTING segments      TYPE ty_segments
                level         TYPE i
      RETURNING VALUE(result) TYPE string.

    METHODS fields_xml
      IMPORTING segment       TYPE REF TO zcl_idoctor_segment
                level         TYPE i
      RETURNING VALUE(result) TYPE string.

    METHODS append_records
      IMPORTING segments      TYPE ty_segments
                parent_number TYPE edidd-psgnum OPTIONAL
      CHANGING  records       TYPE ty_data_records.

    METHODS segment_numbers
      RETURNING VALUE(result) TYPE ty_numbers.

    METHODS number_segments
      IMPORTING segments TYPE ty_segments
      CHANGING  numbers  TYPE ty_numbers.

    METHODS check_level
      IMPORTING parent   TYPE REF TO zcl_idoctor_segment OPTIONAL
                numbers  TYPE ty_numbers
      CHANGING  findings TYPE ty_findings.

    METHODS check_cardinality
      IMPORTING parent   TYPE REF TO zcl_idoctor_segment
                numbers  TYPE ty_numbers
      CHANGING  findings TYPE ty_findings.

    METHODS check_order
      IMPORTING parent   TYPE REF TO zcl_idoctor_segment
                numbers  TYPE ty_numbers
      CHANGING  findings TYPE ty_findings.
ENDCLASS.



CLASS ZCL_IDOCTOR IMPLEMENTATION.


  METHOD constructor.
    me->syntax = syntax.
    control_record = control.
    control_record-idoctp = syntax-idoc_type.
    control_record-cimtyp = syntax-extension.
  ENDMETHOD.


  METHOD create.
    check_syntax( syntax ).
    result = NEW zcl_idoctor( syntax  = syntax
                              control = VALUE #( ) ).
  ENDMETHOD.


  METHOD from_edidd.
    check_syntax( syntax ).
    check_control( syntax  = syntax
                   control = control ).
    check_edidd_table( data ).
    result = NEW zcl_idoctor( syntax  = syntax
                              control = control ).
    result->build( data ).
  ENDMETHOD.


  METHOD to_edidd.
    append_records( EXPORTING segments = top_segments
                    CHANGING  records  = result ).
  ENDMETHOD.


  METHOD control.
    result = control_record.
  ENDMETHOD.


  METHOD segments.
    result = of_type( segments = top_segments
                      name     = name ).
  ENDMETHOD.


  METHOD find_first.
    result = find_first_in( segments = top_segments
                            query    = query_for( name  = name
                                                  field = field
                                                  value = value ) ).
  ENDMETHOD.


  METHOD find_all.
    result = find_in( segments = top_segments
                      query    = query_for( name  = name
                                            field = field
                                            value = value ) ).
  ENDMETHOD.


  METHOD add.
    result = add_child( name ).
  ENDMETHOD.


  METHOD validate.
    check_level( EXPORTING numbers  = segment_numbers( )
                 CHANGING  findings = result ).
  ENDMETHOD.


  METHOD check_syntax.
    IF syntax-segments IS INITIAL.
      RAISE EXCEPTION TYPE zcx_idoctor_error MESSAGE e013(zidoctor) WITH syntax-idoc_type.
    ENDIF.
  ENDMETHOD.


  METHOD check_control.
    IF control-idoctp IS NOT INITIAL
       AND ( control-idoctp <> syntax-idoc_type OR control-cimtyp <> syntax-extension ).
      RAISE EXCEPTION TYPE zcx_idoctor_error
        MESSAGE e010(zidoctor) WITH control-idoctp control-cimtyp syntax-idoc_type syntax-extension.
    ENDIF.
  ENDMETHOD.


  METHOD check_edidd_table.
    DATA record TYPE edidd.

    DATA(table) = CAST cl_abap_tabledescr( cl_abap_typedescr=>describe_by_data( data ) ).
    IF table->get_table_line_type( )->absolute_name
       <> cl_abap_typedescr=>describe_by_data( record )->absolute_name.
      RAISE EXCEPTION TYPE zcx_idoctor_error MESSAGE e014(zidoctor).
    ENDIF.
  ENDMETHOD.


  METHOD of_type.
    DATA(segment_type) = CONV ty_segment_type( to_upper( name ) ).
    LOOP AT segments INTO DATA(segment).
      IF segment_type IS INITIAL OR segment->definition-segment_type = segment_type.
        INSERT segment INTO TABLE result.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD is_character_like.
    CASE descriptor->kind.
      WHEN cl_abap_typedescr=>kind_elem.
        result = xsdbool( descriptor->type_kind = cl_abap_typedescr=>typekind_char
                       OR descriptor->type_kind = cl_abap_typedescr=>typekind_num
                       OR descriptor->type_kind = cl_abap_typedescr=>typekind_date
                       OR descriptor->type_kind = cl_abap_typedescr=>typekind_time ).
      WHEN cl_abap_typedescr=>kind_struct.
        result = are_components_character_like( CAST cl_abap_structdescr( descriptor ) ).
      WHEN OTHERS.
        result = abap_false.
    ENDCASE.
  ENDMETHOD.


  METHOD are_components_character_like.
    DATA(components) = structure->get_components( ).
    LOOP AT components INTO DATA(component).
      IF is_character_like( component-type ) = abap_false.
        RETURN.
      ENDIF.
    ENDLOOP.
    result = abap_true.
  ENDMETHOD.


  METHOD finding.
    result = VALUE #( segment = segment
                      msgid   = sy-msgid
                      msgno   = sy-msgno
                      msgv1   = sy-msgv1
                      msgv2   = sy-msgv2
                      msgv3   = sy-msgv3
                      msgv4   = sy-msgv4
                      text    = text ).
  ENDMETHOD.


  METHOD fits_at.
    DATA(position_before) = COND i( WHEN target_index > 1
                                    THEN siblings[ target_index - 1 ]->definition-position
                                    ELSE definition-position ).
    DATA(position_after) = COND i( WHEN target_index <= lines( siblings )
                                   THEN siblings[ target_index ]->definition-position
                                   ELSE definition-position ).
    result = xsdbool( position_before <= definition-position AND position_after >= definition-position ).
  ENDMETHOD.


  METHOD build.
    DATA record TYPE edidd.
    DATA path TYPE ty_segments.
    DATA parent TYPE REF TO zcl_idoctor_segment.

    LOOP AT data INTO record.
      DATA(record_number) = |{ sy-tabix }|.
      DATA(definition) = definition_of( record-segnam ).
      " the path holds the previous segment and its ancestors; the parent is the nearest one of the parent type
      pop_to_parent( EXPORTING parent_type = definition-parent_type
                     CHANGING  path        = path ).
      CLEAR parent.
      IF path IS NOT INITIAL.
        parent = path[ lines( path ) ].
      ENDIF.
      IF definition-parent_type IS NOT INITIAL AND parent IS NOT BOUND.
        RAISE EXCEPTION TYPE zcx_idoctor_error
          MESSAGE e002(zidoctor) WITH record_number definition-segment_type definition-parent_type.
      ENDIF.
      DATA(segment) = new_segment( definition = definition
                                   parent     = parent ).
      segment->sdata = record-sdata.
      DATA(siblings) = children_of( parent ).
      INSERT segment INTO TABLE siblings->*.
      INSERT segment INTO TABLE path.
    ENDLOOP.
  ENDMETHOD.


  METHOD pop_to_parent.
    WHILE path IS NOT INITIAL.
      IF path[ lines( path ) ]->definition-segment_type = parent_type.
        RETURN.
      ENDIF.
      DELETE path INDEX lines( path ).
    ENDWHILE.
  ENDMETHOD.


  METHOD definition_of.
    DATA(segment_type) = CONV ty_segment_type( to_upper( name ) ).
    result = VALUE #( syntax-segments[ segment_type = segment_type ] OPTIONAL ).
    IF result IS INITIAL.
      RAISE EXCEPTION TYPE zcx_idoctor_error MESSAGE e001(zidoctor) WITH segment_type syntax-idoc_type.
    ENDIF.
  ENDMETHOD.


  METHOD field_definition.
    DATA(name) = CONV ty_field_name( to_upper( field_name ) ).
    result = VALUE #( syntax-fields[ segment_type = segment_type
                                     field_name   = name ] OPTIONAL ).
    IF result IS INITIAL.
      RAISE EXCEPTION TYPE zcx_idoctor_error MESSAGE e006(zidoctor) WITH name segment_type.
    ENDIF.
  ENDMETHOD.


  METHOD query_for.
    " without a segment type every segment matches - and a field exists only within a type
    IF name IS INITIAL.
      IF field IS NOT INITIAL.
        DATA(field_name) = CONV ty_field_name( to_upper( field ) ).
        RAISE EXCEPTION TYPE zcx_idoctor_error MESSAGE e017(zidoctor) WITH field_name.
      ENDIF.
      RETURN.
    ENDIF.
    result-segment_type = definition_of( name )-segment_type.
    IF field IS NOT INITIAL.
      result-field = field_definition( segment_type = result-segment_type
                                       field_name   = field ).
      result-value = value.
    ENDIF.
  ENDMETHOD.


  METHOD find_in.
    LOOP AT segments INTO DATA(segment).
      segment->collect( EXPORTING query   = query
                        CHANGING  matches = result ).
    ENDLOOP.
  ENDMETHOD.


  METHOD find_first_in.
    DATA(matches) = find_in( segments = segments
                             query    = query ).
    IF matches IS NOT INITIAL.
      result = matches[ 1 ].
    ELSEIF query-field IS INITIAL.
      RAISE EXCEPTION TYPE zcx_idoctor_error MESSAGE e015(zidoctor) WITH query-segment_type.
    ELSE.
      RAISE EXCEPTION TYPE zcx_idoctor_error
        MESSAGE e012(zidoctor) WITH query-segment_type query-field-field_name query-value.
    ENDIF.
  ENDMETHOD.


  METHOD add_child.
    IF parent IS BOUND.
      check_attached( parent ).
    ENDIF.
    DATA(definition) = definition_of( name ).
    check_parent( parent     = parent
                  definition = definition ).
    check_room( parent     = parent
                definition = definition ).
    DATA(siblings) = children_of( parent ).
    " behind the siblings the syntax puts before or with it, in front of those it puts behind it
    DATA(target_index) = lines( siblings->* ) + 1.
    LOOP AT siblings->* INTO DATA(sibling).
      IF sibling->definition-position > definition-position.
        target_index = sy-tabix.
        EXIT.
      ENDIF.
    ENDLOOP.
    result = new_segment( definition = definition
                          parent     = parent ).
    INSERT result INTO siblings->* INDEX target_index.
  ENDMETHOD.


  METHOD insert_next_to.
    check_attached( anchor ).
    DATA(definition) = definition_of( name ).
    check_parent( parent     = anchor->parent_segment
                  definition = definition ).
    check_room( parent     = anchor->parent_segment
                definition = definition ).
    DATA(siblings) = children_of( anchor->parent_segment ).
    DATA(target_index) = line_index( siblings->*[ table_line = anchor ] ).
    IF after = abap_true.
      target_index = target_index + 1.
    ENDIF.
    IF fits_at( siblings     = siblings->*
                target_index = target_index
                definition   = definition ) = abap_false.
      RAISE EXCEPTION TYPE zcx_idoctor_error
        MESSAGE e005(zidoctor) WITH definition-segment_type anchor->definition-segment_type.
    ENDIF.
    result = new_segment( definition = definition
                          parent     = anchor->parent_segment ).
    INSERT result INTO siblings->* INDEX target_index.
  ENDMETHOD.


  METHOD remove_segment.
    check_attached( segment ).
    DATA(siblings) = children_of( segment->parent_segment ).
    DELETE siblings->* WHERE table_line = segment.
    CLEAR segment->parent_segment.
  ENDMETHOD.


  METHOD check_parent.
    DATA(parent_type) = COND ty_segment_type( WHEN parent IS BOUND THEN parent->definition-segment_type ).
    IF definition-parent_type <> parent_type.
      DATA(expected) = COND ty_segment_type( WHEN definition-parent_type IS INITIAL
                                             THEN syntax-idoc_type
                                             ELSE definition-parent_type ).
      DATA(actual) = label_of( parent ).
      RAISE EXCEPTION TYPE zcx_idoctor_error
        MESSAGE e003(zidoctor) WITH definition-segment_type expected actual.
    ENDIF.
  ENDMETHOD.


  METHOD check_room.
    DATA(siblings) = children_of( parent ).
    DATA(occurrences) = lines( of_type( segments = siblings->*
                                        name     = definition-segment_type ) ).
    IF occurrences >= definition-max_occurrence.
      DATA(occurrence_text) = |{ occurrences }|.
      DATA(maximum_text) = |{ definition-max_occurrence }|.
      DATA(label) = label_of( parent ).
      RAISE EXCEPTION TYPE zcx_idoctor_error
        MESSAGE e004(zidoctor) WITH definition-segment_type occurrence_text label maximum_text.
    ENDIF.
  ENDMETHOD.


  METHOD check_attached.
    IF is_attached( segment ) = abap_false.
      RAISE EXCEPTION TYPE zcx_idoctor_error MESSAGE e011(zidoctor) WITH segment->definition-segment_type.
    ENDIF.
  ENDMETHOD.


  METHOD is_attached.
    DATA(node) = segment.
    WHILE node->parent_segment IS BOUND.
      IF NOT line_exists( node->parent_segment->child_segments[ table_line = node ] ).
        RETURN.
      ENDIF.
      node = node->parent_segment.
    ENDWHILE.
    result = xsdbool( line_exists( top_segments[ table_line = node ] ) ).
  ENDMETHOD.


  METHOD check_data_type.
    DATA(descriptor) = cl_abap_typedescr=>describe_by_data( data ).
    DATA(type_name) = descriptor->get_relative_name( ).
    IF is_character_like( descriptor ) = abap_false
       OR descriptor->length > max_data_length * cl_abap_char_utilities=>charsize.
      RAISE EXCEPTION TYPE zcx_idoctor_error MESSAGE e008(zidoctor) WITH type_name definition-segment_type.
    ENDIF.
    " a DDIC structure names the segment it was made for - a different one is a mix-up
    IF descriptor->kind = cl_abap_typedescr=>kind_struct
       AND descriptor->is_ddic_type( ) = abap_true
       AND type_name <> definition-segment_type
       AND type_name <> definition-definition.
      RAISE EXCEPTION TYPE zcx_idoctor_error MESSAGE e009(zidoctor) WITH type_name definition-segment_type.
    ENDIF.
  ENDMETHOD.


  METHOD children_of.
    IF parent IS BOUND.
      result = REF #( parent->child_segments ).
    ELSE.
      result = REF #( top_segments ).
    ENDIF.
  ENDMETHOD.


  METHOD new_segment.
    result = NEW zcl_idoctor_segment( idoc       = me
                                      definition = definition
                                      parent     = parent ).
  ENDMETHOD.


  METHOD label_of.
    IF parent IS NOT BOUND.
      result = syntax-idoc_type.
      RETURN.
    ENDIF.
    result = parent->definition-segment_type.
    IF line_exists( numbers[ segment = parent ] ).
      result = |{ result } { numbers[ segment = parent ]-number }|.
    ENDIF.
  ENDMETHOD.


  METHOD append_records.
    LOOP AT segments INTO DATA(segment).
      DATA(record) = VALUE edidd( mandt  = control_record-mandt
                                  docnum = control_record-docnum
                                  segnum = lines( records ) + 1
                                  segnam = segment->definition-segment_type
                                  psgnum = parent_number
                                  hlevel = segment->definition-hierarchy_level
                                  sdata  = segment->sdata ).
      INSERT record INTO TABLE records.
      append_records( EXPORTING segments      = segment->child_segments
                                parent_number = record-segnum
                      CHANGING  records       = records ).
    ENDLOOP.
  ENDMETHOD.


  METHOD number_segments.
    LOOP AT segments INTO DATA(segment).
      INSERT VALUE #( segment = segment
                      number  = lines( numbers ) + 1 ) INTO TABLE numbers.
      number_segments( EXPORTING segments = segment->child_segments
                       CHANGING  numbers  = numbers ).
    ENDLOOP.
  ENDMETHOD.


  METHOD check_level.
    check_cardinality( EXPORTING parent   = parent
                                 numbers  = numbers
                       CHANGING  findings = findings ).
    check_order( EXPORTING parent   = parent
                           numbers  = numbers
                 CHANGING  findings = findings ).
    DATA(children) = children_of( parent ).
    LOOP AT children->* INTO DATA(child).
      check_level( EXPORTING parent   = child
                             numbers  = numbers
                   CHANGING  findings = findings ).
    ENDLOOP.
  ENDMETHOD.


  METHOD check_cardinality.
    DATA(owner_type) = COND ty_segment_type( WHEN parent IS BOUND THEN parent->definition-segment_type ).
    DATA(children) = children_of( parent ).
    DATA(label) = label_of( parent  = parent
                            numbers = numbers ).
    LOOP AT syntax-segments INTO DATA(definition) USING KEY by_parent WHERE parent_type = owner_type.
      DATA(instances) = of_type( segments = children->*
                                 name     = definition-segment_type ).
      DATA(occurrences) = lines( instances ).
      DATA(occurrence_text) = |{ occurrences }|.
      IF occurrences < definition-min_occurrence.
        DATA(minimum_text) = |{ definition-min_occurrence }|.
        MESSAGE e020(zidoctor) WITH definition-segment_type occurrence_text label minimum_text INTO DATA(text).
        INSERT finding( segment = parent
                        text    = text ) INTO TABLE findings.
      ELSEIF occurrences > definition-max_occurrence.
        DATA(maximum_text) = |{ definition-max_occurrence }|.
        MESSAGE e021(zidoctor) WITH definition-segment_type occurrence_text label maximum_text INTO text.
        INSERT finding( segment = instances[ occurrences ]
                        text    = text ) INTO TABLE findings.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD check_order.
    DATA previous TYPE REF TO zcl_idoctor_segment.

    DATA(children) = children_of( parent ).
    LOOP AT children->* INTO DATA(child).
      IF previous IS BOUND AND child->definition-position < previous->definition-position.
        DATA(number) = numbers[ segment = child ]-number.
        MESSAGE e022(zidoctor) WITH child->definition-segment_type number previous->definition-segment_type
          INTO DATA(text).
        INSERT finding( segment = child
                        text    = text ) INTO TABLE findings.
      ENDIF.
      previous = child.
    ENDLOOP.
  ENDMETHOD.


  METHOD control_xml.
    DATA(control) = flat_control( ).
    DATA(structure) = CAST cl_abap_structdescr( cl_abap_typedescr=>describe_by_data( control ) ).
    " the control record is character-like, so each field is a slice of its fixed-length line
    DATA(line) = fixed_width( control ).
    DATA(offset) = 0.
    result = |{ indentation( level ) }<{ control_record_name } SEGMENT="1">{ cl_abap_char_utilities=>newline }|.
    LOOP AT structure->components INTO DATA(component).
      DATA(length) = component-length / cl_abap_char_utilities=>charsize.
      DATA(value) = condense( val = substring( val = line
                                               off = offset
                                               len = length )
                              del = ` ` ).
      IF value CN ` 0`.
        result = result && xml_element( name  = component-name
                                        value = value
                                        level = level + 1 ).
      ENDIF.
      offset = offset + length.
    ENDLOOP.
    result = |{ result }{ indentation( level ) }</{ control_record_name }>{ cl_abap_char_utilities=>newline }|.
  ENDMETHOD.


  METHOD fields_xml.
    DATA(fields) = VALUE ty_field_definitions_by_offset(
                     FOR syntax_field IN syntax-fields WHERE ( segment_type = segment->definition-segment_type )
                     ( syntax_field ) ).
    LOOP AT fields INTO DATA(field).
      DATA(value) = CONV string( segment->sdata+field-offset(field-length) ).
      IF value IS NOT INITIAL.
        result = result && xml_element( name  = field-field_name
                                        value = value
                                        level = level ).
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD find_by_number.
    DATA(segment_number) = CONV edidd-segnum( number ).
    DATA(numbers) = segment_numbers( ).
    result = VALUE #( numbers[ number = segment_number ]-segment OPTIONAL ).
    IF result IS NOT BOUND.
      RAISE EXCEPTION TYPE zcx_idoctor_error MESSAGE e016(zidoctor) WITH segment_number.
    ENDIF.
  ENDMETHOD.


  METHOD fixed_width.
    " the records are character-like structures; moved into one field they keep their layout
    DATA line TYPE c LENGTH 1100.

    line = record.
    " the width is the sum of the field lengths, so that trailing blank fields are kept
    DATA(structure) = CAST cl_abap_structdescr( cl_abap_typedescr=>describe_by_data( record ) ).
    DATA(width) = 0.
    LOOP AT structure->components INTO DATA(component).
      width = width + component-length / cl_abap_char_utilities=>charsize.
    ENDLOOP.
    result = |{ line WIDTH = width }|.
  ENDMETHOD.


  METHOD flat_control.
    result = CORRESPONDING #( control_record ).
    result-tabnam  = control_record_name.
    result-idoctyp = control_record-idoctp.
  ENDMETHOD.


  METHOD flat_segment_name.
    " files carry the segment definition - the version of the segment - where the syntax knows it
    result = VALUE #( syntax-segments[ segment_type = segment_type ]-definition OPTIONAL ).
    IF result IS INITIAL.
      result = segment_type.
    ENDIF.
  ENDMETHOD.


  METHOD indentation.
    result = repeat( val = ` `
                     occ = level * xml_indentation ).
  ENDMETHOD.


  METHOD number_of.
    check_attached( segment ).
    DATA(numbers) = segment_numbers( ).
    result = numbers[ segment = segment ]-number.
  ENDMETHOD.


  METHOD segments_xml.
    DATA(newline) = cl_abap_char_utilities=>newline.
    LOOP AT segments INTO DATA(segment).
      DATA(name) = xml_name( segment->definition-segment_type ).
      result = |{ result }{ indentation( level ) }<{ name } SEGMENT="1">{ newline }|
            && fields_xml( segment = segment
                           level   = level + 1 )
            && segments_xml( segments = segment->child_segments
                             level    = level + 1 )
            && |{ indentation( level ) }</{ name }>{ newline }|.
    ENDLOOP.
  ENDMETHOD.


  METHOD segment_numbers.
    " numbered as append_records( ) numbers the data records: depth first, in document order
    number_segments( EXPORTING segments = top_segments
                     CHANGING  numbers  = result ).
  ENDMETHOD.


  METHOD to_flat_file.
    DATA(separator) = COND string( WHEN line_break IS SUPPLIED THEN line_break
                                   ELSE cl_abap_char_utilities=>newline ).
    result = |{ fixed_width( flat_control( ) ) }{ separator }|.
    DATA(records) = to_edidd( ).
    LOOP AT records INTO DATA(record).
      DATA(data_record) = CORRESPONDING edi_dd40( record ).
      data_record-segnam = flat_segment_name( record-segnam ).
      result = |{ result }{ fixed_width( data_record ) }{ separator }|.
    ENDLOOP.
  ENDMETHOD.


  METHOD to_xml.
    DATA(newline) = cl_abap_char_utilities=>newline.
    DATA(root) = xml_name( COND string( WHEN control_record-cimtyp IS NOT INITIAL
                                        THEN control_record-cimtyp
                                        ELSE control_record-idoctp ) ).
    result = |<?xml version="1.0"?>{ newline }<{ root }>{ newline }|
          && |{ indentation( 1 ) }<IDOC BEGIN="1">{ newline }|
          && control_xml( 2 )
          && segments_xml( segments = top_segments
                           level    = 2 )
          && |{ indentation( 1 ) }</IDOC>{ newline }</{ root }>{ newline }|.
  ENDMETHOD.


  METHOD xml_element.
    result = |{ indentation( level ) }<{ xml_name( name ) }>|
          && |{ escape( val    = value
                        format = cl_abap_format=>e_xml_text ) }|
          && |</{ xml_name( name ) }>{ cl_abap_char_utilities=>newline }|.
  ENDMETHOD.


  METHOD xml_name.
    " SAP writes the slash of a namespace as "_-" in XML names, e.g. /ABC/E1HEAD as _-ABC_-E1HEAD
    result = replace( val  = condense( name )
                      sub  = `/`
                      with = `_-`
                      occ  = 0 ).
  ENDMETHOD.
ENDCLASS.
