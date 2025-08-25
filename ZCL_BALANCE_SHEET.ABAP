CLASS zcl_balance_sheet DEFINITION.
  PUBLIC SECTION.

    METHODS constructor
      IMPORTING
        date_report  TYPE gjahr
        company_code TYPE bukrs
        language     TYPE spras
        account_plan TYPE ktopl.

    METHODS get_balance_sheet
      EXPORTING
        lt_balance_sheet TYPE zc2b_balance_output_tt.

  PROTECTED SECTION.
  PRIVATE SECTION.

    METHODS get_data.
    METHODS get_glaccounts.
    METHODS get_glaccounts_bukrs.
    METHODS search_account_movements.
    METHODS set_descritive.
    METHODS set_balance_sheet.
    METHODS set_glaccount_bukrs.
    METHODS set_glaccount_movements.

    TYPES: BEGIN OF ty_saknr,
             saknr TYPE saknr,
           END OF ty_saknr.
    DATA: gt_saknr TYPE TABLE OF ty_saknr.

    DATA: gv_date_report1 TYPE gjahr,
          gv_date_report2 TYPE gjahr.

    DATA: gv_bukrs TYPE bukrs,
          gv_spras TYPE spras,
          gv_ktopl TYPE ktopl.

    DATA: gt_skat      TYPE STANDARD TABLE OF skat,      "Mestre de contas do Razão (plano de contas: denominação)
          gt_ska1      TYPE STANDARD TABLE OF ska1,      "Mestre de contas do Razão (plano de contas)
          gt_skb1      TYPE STANDARD TABLE OF skb1,      "Mestre da Conta do Razão (empresa)
          gt_bseg      TYPE STANDARD TABLE OF bseg,      "Segmento do documento contabilidade financeira
          gt_faglflext TYPE STANDARD TABLE OF faglflext. "Razão: totais

    DATA: gt_balance_sheet TYPE zc2b_balance_output_tt,
          gs_balance_sheet TYPE zc2b_balance_output_st.

ENDCLASS.

CLASS zcl_balance_sheet IMPLEMENTATION.

  METHOD constructor.

    gv_date_report1 = date_report.
    gv_bukrs        = company_code.
    gv_spras        = language.
    gv_ktopl        = account_plan.

    get_data( ).

  ENDMETHOD.

  METHOD get_data.

    get_glaccounts( ).
    get_glaccounts_bukrs( ).
    search_account_movements( ).

  ENDMETHOD.

  METHOD get_glaccounts.

    SELECT * FROM ska1
    INTO TABLE gt_ska1
    WHERE ktopl EQ gv_ktopl.

  ENDMETHOD.

  METHOD get_glaccounts_bukrs.

    LOOP AT gt_ska1 INTO DATA(ls_ska1).
      SELECT * FROM skb1
      INTO TABLE @DATA(lt_temp_skb1)
      WHERE bukrs EQ @gv_bukrs
      AND   saknr EQ @ls_ska1-saknr.

      APPEND LINES OF lt_temp_skb1 TO gt_skb1.
      SORT gt_skb1 BY saknr ASCENDING.
    ENDLOOP.

  ENDMETHOD.

  METHOD search_account_movements.

    LOOP AT gt_skb1 INTO DATA(ls_skb1).

      SELECT * FROM faglflext
      INTO TABLE @DATA(lt_temp_faglflext)
      WHERE ryear  EQ @gv_date_report1
      AND   racct  EQ @ls_skb1-saknr
      AND   rbukrs EQ @ls_skb1-bukrs.

      IF sy-subrc EQ 0.
        APPEND LINES OF lt_temp_faglflext TO gt_faglflext.
        SORT gt_bseg BY saknr ASCENDING.
      ENDIF.
    ENDLOOP.

    LOOP AT gt_faglflext INTO DATA(ls_faglflext).
      APPEND ls_faglflext-racct TO gt_saknr.
    ENDLOOP.
    DELETE ADJACENT DUPLICATES FROM gt_saknr.

  ENDMETHOD.

  METHOD set_balance_sheet.

    set_glaccount_bukrs( ).
    set_descritive( ).
    set_glaccount_movements( ).

  ENDMETHOD.

  METHOD set_glaccount_bukrs.

    LOOP AT gt_saknr INTO DATA(ls_saknr).
      IF sy-subrc EQ 0.
        gs_balance_sheet-bukrs = gv_bukrs.
        gs_balance_sheet-saknr = ls_saknr.
        APPEND gs_balance_sheet TO gt_balance_sheet.
        CLEAR gs_balance_sheet.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.

  METHOD set_descritive.

    LOOP AT gt_balance_sheet INTO gs_balance_sheet.
      SELECT SINGLE txt50 FROM skat INTO @DATA(lv_descr) WHERE saknr EQ @gs_balance_sheet-saknr AND spras EQ @gv_spras AND ktopl EQ @gv_ktopl.
      gs_balance_sheet-saknr_descr = lv_descr.
      SHIFT gs_balance_sheet-saknr_descr LEFT DELETING LEADING space.
      MODIFY gt_balance_sheet FROM gs_balance_sheet.
      CLEAR gs_balance_sheet.
    ENDLOOP.

  ENDMETHOD.

  METHOD set_glaccount_movements.

*    "get all movements
*    SELECT *
*    FROM faglflexa
*    INTO TABLE @DATA(lt_faglflexa)
*    FOR ALL ENTRIES IN @gt_saknr
*    WHERE ryear EQ @gv_date_report1
*    AND   racct EQ @gt_saknr-saknr.
*
*    LOOP AT lt_faglflexa INTO DATA(ls_faglflexa).
*      READ TABLE gt_balance_sheet INTO DATA(ls_balance) WITH KEY saknr = ls_faglflexa-racct.
*      IF sy-subrc EQ 0.
*        ls_balance-belnr = ls_faglflexa-docnr.
*        ls_balance-dmbtr = ls_faglflexa-hsl.
*        APPEND ls_balance TO gt_balance_sheet.
*      ENDIF.
*    ENDLOOP.
*
*    "order table
    DELETE gt_balance_sheet WHERE belnr EQ ''.
*    SORT gt_balance_sheet BY saknr ASCENDING.

* 1 - GET Estrutura de balanço - Tabela fagl_011ZC

    SELECT *
    FROM fagl_011zc
    INTO TABLE @DATA(it_temp_balance_sheet)
    WHERE versn EQ 'BSPT'.

* 2 - Loop estr. bal. - select faglflexa apenas com as contas de cada estrutura (11, 21,22) --> Excluir tipo movimento = ''.

    LOOP AT it_temp_balance_sheet INTO DATA(ls_temp).

      SELECT *
      FROM faglflexa
      INTO TABLE @DATA(lt_temp_movements)
      WHERE ryear  EQ @gv_date_report1
      AND   racct  BETWEEN @ls_temp-vonkt AND @ls_temp-biskt
      AND   rbukrs EQ @gv_bukrs.
*      AND   rmvct NE ' '.

      "----------------------------------------------------
      "testes lt_temp_movements.
      IF sy-subrc EQ 0.
        DATA: lv_numoves TYPE i.
        lv_numoves = lines( lt_temp_movements ).
        DATA: lv_countmoves TYPE i VALUE 0.
        LOOP AT lt_temp_movements INTO DATA(ls_temp_mov).
          IF lv_countmoves LT lv_numoves / 2.
            ls_temp_mov-rmvct = '001'.
            MODIFY lt_temp_movements FROM ls_temp_mov.
          ENDIF.
          IF lv_countmoves GE lv_numoves / 2.
            ls_temp_mov-rmvct = '002'.
            MODIFY lt_temp_movements FROM ls_temp_mov.
          ENDIF.
          ADD 1 TO lv_countmoves.
        ENDLOOP.
      ENDIF.
      CLEAR lv_numoves.
      CLEAR lv_countmoves.
      "----------------------------------------------------

      " 3-  Somatório das contas por conta + tipo mov
      IF sy-subrc EQ 0.

        "get first movement
        DATA: lv_old_movement TYPE rmvct.
        DATA: lv_old_racct TYPE racct.
        READ TABLE lt_temp_movements INTO DATA(ls_movement) INDEX 1.
        lv_old_movement = ls_movement-rmvct.
        lv_old_racct    = ls_movement-racct.

        SORT lt_temp_movements BY racct ASCENDING.
        LOOP AT lt_temp_movements INTO DATA(ls_movement2).
          IF lv_old_movement NE ls_movement2-rmvct OR lv_old_racct NE ls_movement2-racct.
            APPEND gs_balance_sheet TO gt_balance_sheet.
            CLEAR gs_balance_sheet.
          ENDIF.

          gs_balance_sheet-bukrs = ls_movement2-rbukrs.
          gs_balance_sheet-saknr = ls_movement2-racct.
          gs_balance_sheet-dmbtr = gs_balance_sheet-dmbtr + ls_movement2-hsl.
          gs_balance_sheet-bewar = ls_movement2-rmvct.
          SELECT SINGLE txt50 FROM skat INTO @DATA(lv_descr) WHERE saknr EQ @ls_movement2-racct AND spras EQ @gv_spras AND ktopl EQ @gv_ktopl.
          gs_balance_sheet-saknr_descr = lv_descr.

          lv_old_movement = ls_movement2-rmvct.
          lv_old_racct    = ls_movement2-racct.
        ENDLOOP.
      ENDIF.

      " garante que o último acumulado vá para a tabela
      IF gs_balance_sheet IS NOT INITIAL.
        APPEND gs_balance_sheet TO gt_balance_sheet.
        CLEAR gs_balance_sheet.
      ENDIF.

    ENDLOOP.

    SORT gt_balance_sheet BY saknr ASCENDING.
    DELETE gt_balance_sheet WHERE saknr IS INITIAL.

  ENDMETHOD.

  METHOD get_balance_sheet.

    set_balance_sheet( ).
    lt_balance_sheet = gt_balance_sheet.

  ENDMETHOD.

ENDCLASS.
