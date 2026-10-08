"! The one exception of IDoctor. Every text lives in message class ZIDOCTOR and is chosen
"! where the error is raised (RAISE EXCEPTION TYPE zcx_idoctor_error MESSAGE ...), so the
"! T100 key (message class and number) tells a caller which error it is, and the message
"! variables carry the details.
CLASS zcx_idoctor_error DEFINITION
  PUBLIC
  INHERITING FROM cx_static_check
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_t100_dyn_msg.

    "! Called by the runtime for RAISE EXCEPTION TYPE ... MESSAGE and ... USING MESSAGE, which fill
    "! the T100 key and the message variables after construction.
    "!
    "! @parameter textid   | T100 key of the text; the default text when initial
    "! @parameter previous | Exception that caused this one
    METHODS constructor
      IMPORTING
        textid   TYPE scx_t100key OPTIONAL
        previous TYPE REF TO cx_root OPTIONAL.
ENDCLASS.


CLASS zcx_idoctor_error IMPLEMENTATION.

  METHOD constructor ##ADT_SUPPRESS_GENERATION.
    super->constructor( previous = previous ).
    CLEAR me->textid.
    IF textid IS INITIAL.
      if_t100_message~t100key = if_t100_message=>default_textid.
    ELSE.
      if_t100_message~t100key = textid.
    ENDIF.
  ENDMETHOD.

ENDCLASS.

