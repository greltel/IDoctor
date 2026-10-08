"! A segment of an IDoc - one node of the tree that zcl_idoctor holds. It reads and writes its
"! data as a whole structure or field by field, navigates and searches the segments below it,
"! and hands every structural change (add, insert, remove) to its IDoc, which owns the rules.
CLASS zcl_idoctor_segment DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE
  GLOBAL FRIENDS zcl_idoctor.

  PUBLIC SECTION.
    "! Segments are created by their IDoc only, through its add and insert methods.
    "!
    "! @parameter idoc       | IDoc the segment belongs to
    "! @parameter definition | Definition of the segment type
    "! @parameter parent     | Parent segment; not bound for a top-level segment
    METHODS constructor
      IMPORTING idoc       TYPE REF TO zcl_idoctor
                definition TYPE zcl_idoctor=>ty_segment_definition
                parent     TYPE REF TO zcl_idoctor_segment OPTIONAL.

    "! @parameter result | Segment type, e.g. E1EDP01
    METHODS name
      RETURNING VALUE(result) TYPE zcl_idoctor=>ty_segment_type.

    "! @parameter result | IDoc the segment belongs to
    METHODS idoc
      RETURNING VALUE(result) TYPE REF TO zcl_idoctor.

    "! @parameter result | Parent segment; not bound for a top-level segment and after remove( )
    METHODS parent
      RETURNING VALUE(result) TYPE REF TO zcl_idoctor_segment.

    "! Child segments.
    "!
    "! @parameter name   | Only children of this segment type; all children when initial
    "! @parameter result | Children in document order
    METHODS children
      IMPORTING name          TYPE zcl_idoctor=>ty_segment_type OPTIONAL
      RETURNING VALUE(result) TYPE zcl_idoctor=>ty_segments.

    "! Reads one field of the segment data.
    "!
    "! @parameter field  | Field name, e.g. CURCY
    "! @parameter result | Field content without trailing blanks
    "! @raising zcx_idoctor_error | The field is not defined for the segment type
    METHODS get_value
      IMPORTING field         TYPE zcl_idoctor=>ty_field_name
      RETURNING VALUE(result) TYPE string
      RAISING   zcx_idoctor_error.

    "! Writes one field of the segment data, left-aligned; the rest of the field is cleared.
    "!
    "! @parameter field | Field name, e.g. CURCY
    "! @parameter value | New content; must fit into the field
    "! @raising zcx_idoctor_error | The field is not defined for the segment type, or the value
    "!                             is longer than the field
    METHODS set_value
      IMPORTING field TYPE zcl_idoctor=>ty_field_name
                value TYPE clike
      RAISING   zcx_idoctor_error.

    "! Reads the whole segment data into a structure, e.g. one typed with the DDIC structure of
    "! the segment type (E1EDP01).
    "!
    "! @parameter data | Character-like structure or field of at most 1000 characters; a DDIC
    "!                  structure must be the one of the segment type or of its definition
    "! @raising zcx_idoctor_error | The type of data does not fit the segment
    METHODS get_data
      EXPORTING data TYPE any
      RAISING   zcx_idoctor_error.

    "! Replaces the whole segment data with the content of a structure.
    "!
    "! @parameter data | Character-like structure or field of at most 1000 characters; a DDIC
    "!                  structure must be the one of the segment type or of its definition
    "! @raising zcx_idoctor_error | The type of data does not fit the segment
    METHODS set_data
      IMPORTING data TYPE any
      RAISING   zcx_idoctor_error.

    "! First segment below this one with the given type and, when a field is given, field value.
    "!
    "! @parameter name   | Segment type
    "! @parameter field  | Field to compare; when initial, every segment of the type matches
    "! @parameter value  | Content the field must have; compared without trailing blanks
    "! @parameter result | First match in document order
    "! @raising zcx_idoctor_error | The segment type or field is not defined, or no segment matches
    METHODS find_first
      IMPORTING name          TYPE zcl_idoctor=>ty_segment_type
                field         TYPE zcl_idoctor=>ty_field_name OPTIONAL
                value         TYPE clike OPTIONAL
      RETURNING VALUE(result) TYPE REF TO zcl_idoctor_segment
      RAISING   zcx_idoctor_error.

    "! All segments below this one with the given type and, when a field is given, field value.
    "!
    "! @parameter name   | Segment type
    "! @parameter field  | Field to compare; when initial, every segment of the type matches
    "! @parameter value  | Content the field must have; compared without trailing blanks
    "! @parameter result | Matches in document order; empty when there is none
    "! @raising zcx_idoctor_error | The segment type or field is not defined
    METHODS find_all
      IMPORTING name          TYPE zcl_idoctor=>ty_segment_type
                field         TYPE zcl_idoctor=>ty_field_name OPTIONAL
                value         TYPE clike OPTIONAL
      RETURNING VALUE(result) TYPE zcl_idoctor=>ty_segments
      RAISING   zcx_idoctor_error.

    "! Adds a child segment where the syntax puts it: after the children of its own type,
    "! before the segment types that follow it in the IDoc type.
    "!
    "! @parameter name   | Segment type of the child
    "! @parameter result | The new, empty segment
    "! @raising zcx_idoctor_error | The type is not defined or is no child type of this segment,
    "!                             it already occurs here as often as allowed, or this segment
    "!                             was removed
    METHODS add
      IMPORTING name          TYPE zcl_idoctor=>ty_segment_type
      RETURNING VALUE(result) TYPE REF TO zcl_idoctor_segment
      RAISING   zcx_idoctor_error.

    "! Inserts a new sibling directly before this segment.
    "!
    "! @parameter name   | Segment type of the new segment
    "! @parameter result | The new, empty segment
    "! @raising zcx_idoctor_error | The type is not defined or belongs under another parent, it
    "!                             already occurs here as often as allowed, the place breaks the
    "!                             order of the syntax, or this segment was removed
    METHODS insert_before
      IMPORTING name          TYPE zcl_idoctor=>ty_segment_type
      RETURNING VALUE(result) TYPE REF TO zcl_idoctor_segment
      RAISING   zcx_idoctor_error.

    "! Inserts a new sibling directly after this segment.
    "!
    "! @parameter name   | Segment type of the new segment
    "! @parameter result | The new, empty segment
    "! @raising zcx_idoctor_error | The type is not defined or belongs under another parent, it
    "!                             already occurs here as often as allowed, the place breaks the
    "!                             order of the syntax, or this segment was removed
    METHODS insert_after
      IMPORTING name          TYPE zcl_idoctor=>ty_segment_type
      RETURNING VALUE(result) TYPE REF TO zcl_idoctor_segment
      RAISING   zcx_idoctor_error.

    "! Removes this segment and everything below it from the IDoc. Whether the IDoc still has
    "! every mandatory segment afterwards is reported by validate( ) of the IDoc.
    "!
    "! @raising zcx_idoctor_error | The segment was removed already
    METHODS remove
      RAISING zcx_idoctor_error.

  PRIVATE SECTION.
    DATA root TYPE REF TO zcl_idoctor.
    DATA definition TYPE zcl_idoctor=>ty_segment_definition.
    DATA parent_segment TYPE REF TO zcl_idoctor_segment.
    DATA child_segments TYPE zcl_idoctor=>ty_segments.
    DATA sdata TYPE edidd-sdata.

    METHODS collect
      IMPORTING query   TYPE zcl_idoctor=>ty_query
      CHANGING  matches TYPE zcl_idoctor=>ty_segments.
ENDCLASS.


CLASS zcl_idoctor_segment IMPLEMENTATION.

  METHOD constructor.
    root = idoc.
    me->definition = definition.
    parent_segment = parent.
  ENDMETHOD.


  METHOD name.
    result = definition-segment_type.
  ENDMETHOD.


  METHOD idoc.
    result = root.
  ENDMETHOD.


  METHOD parent.
    result = parent_segment.
  ENDMETHOD.


  METHOD children.
    result = zcl_idoctor=>of_type( segments = child_segments
                                   name     = name ).
  ENDMETHOD.


  METHOD get_value.
    DATA(field_definition) = root->field_definition( segment_type = definition-segment_type
                                                     field_name   = field ).
    result = sdata+field_definition-offset(field_definition-length).
  ENDMETHOD.


  METHOD set_value.
    DATA(field_definition) = root->field_definition( segment_type = definition-segment_type
                                                     field_name   = field ).
    IF strlen( value ) > field_definition-length.
      DATA(value_text) = CONV string( value ).
      DATA(length_text) = |{ field_definition-length }|.
      RAISE EXCEPTION TYPE zcx_idoctor_error
        MESSAGE e007(zidoctor) WITH value_text field_definition-field_name length_text.
    ENDIF.
    sdata+field_definition-offset(field_definition-length) = value.
  ENDMETHOD.


  METHOD get_data.
    CLEAR data.
    root->check_data_type( data       = data
                           definition = definition ).
    data = sdata.
  ENDMETHOD.


  METHOD set_data.
    root->check_data_type( data       = data
                           definition = definition ).
    sdata = data.
  ENDMETHOD.


  METHOD find_first.
    result = root->find_first_in( segments = child_segments
                                  query    = root->query_for( name  = name
                                                              field = field
                                                              value = value ) ).
  ENDMETHOD.


  METHOD find_all.
    result = root->find_in( segments = child_segments
                            query    = root->query_for( name  = name
                                                        field = field
                                                        value = value ) ).
  ENDMETHOD.


  METHOD add.
    result = root->add_child( parent = me
                              name   = name ).
  ENDMETHOD.


  METHOD insert_before.
    result = root->insert_next_to( anchor = me
                                   name   = name
                                   after  = abap_false ).
  ENDMETHOD.


  METHOD insert_after.
    result = root->insert_next_to( anchor = me
                                   name   = name
                                   after  = abap_true ).
  ENDMETHOD.


  METHOD remove.
    root->remove_segment( me ).
  ENDMETHOD.


  METHOD collect.
    IF definition-segment_type = query-segment_type
       AND ( query-field IS INITIAL OR sdata+query-field-offset(query-field-length) = query-value ).
      INSERT me INTO TABLE matches.
    ENDIF.
    LOOP AT child_segments INTO DATA(child).
      child->collect( EXPORTING query   = query
                      CHANGING  matches = matches ).
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.

