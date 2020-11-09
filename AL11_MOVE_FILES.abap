*&---------------------------------------------------------------------*
*& Report ZFI_P_JV_UPLOAD_AL11_UP_TEST
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
REPORT ZFI_P_JV_UPLOAD_AL11_UP_TEST.

*&---------------------------------------------------------------------*
*&---------------------------------------------------------------------*
DATA: filename type string,
      directory_uploaded_and_file TYPE string.
DATA: dir_from TYPE string,
      dir_to   TYPE string.
DATA: del_dir  TYPE string.

*&---------------------------------------------------------------------*
*&---------------------------------------------------------------------*
SELECTION-SCREEN BEGIN OF BLOCK block1 WITH FRAME TITLE text-001.
PARAMETERS: P_CHKU AS CHECKBOX USER-COMMAND USR,
            P_CHKM AS CHECKBOX USER-COMMAND USR,
            P_CHKD AS CHECKBOX USER-COMMAND USR.
SELECTION-SCREEN END OF BLOCK block1.
SELECTION-SCREEN BEGIN OF BLOCK block3.
PARAMETERS: P_FILE  TYPE STRING MODIF ID MD1 LOWER CASE,
            P_DIR   TYPE eps2filnam MODIF ID MD1 DEFAULT '/directoryX/../inbound/'.
PARAMETERS: P_MOVE  TYPE STRING MODIF ID MD1 LOWER CASE,
            P_FROM  TYPE eps2filnam MODIF ID MD1 DEFAULT '/directoryX/../sth/files/',
            P_TO    TYPE eps2filnam MODIF ID MD1 DEFAULT '/directoryX/../sth_else/files/'.
PARAMETERS: P_FDEL  TYPE STRING MODIF ID MD1 LOWER CASE,
            P_DDEL  TYPE eps2filnam MODIF ID MD1 DEFAULT '/directoryX/../sth_else/files/'.
SELECTION-SCREEN END OF BLOCK block3.

*&---------------------------------------------------------------------*
*&---------------------------------------------------------------------*
AT SELECTION-SCREEN OUTPUT.
LOOP AT SCREEN.
  IF screen-name CS 'P_FILE' OR screen-name CS 'P_DIR'.
    IF P_CHKU = ''.
      screen-input = 0.
      screen-invisible = 1.
    ELSE.
      screen-input = 1.
      screen-invisible = 0.
    ENDIF.
    MODIFY SCREEN.
  ENDIF.
  IF screen-name CS 'P_MOVE' OR screen-name CS 'P_FROM' OR screen-name CS 'P_TO'.
    IF P_CHKM = ''.
      screen-input = 0.
      screen-invisible = 1.
    ELSE.
      screen-input = 1.
      screen-invisible = 0.
    ENDIF.
    MODIFY SCREEN.
  ENDIF.
  IF screen-name CS 'P_FDEL' OR screen-name CS 'P_DDEL'.
    IF P_CHKD = ''.
      screen-input = 0.
      screen-invisible = 1.
    ELSE.
      screen-input = 1.
      screen-invisible = 0.
    ENDIF.
    MODIFY SCREEN.
  ENDIF.
ENDLOOP.

*&---------------------------------------------------------------------*
*&---------------------------------------------------------------------*
AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_file.
PERFORM f4_file_open_dialog CHANGING p_file.

*&---------------------------------------------------------------------*
*&---------------------------------------------------------------------*
START-OF-SELECTION.
IF P_CHKU = 'X'.
  PERFORM get_filename.
  CONCATENATE P_DIR filename INTO directory_uploaded_and_file.
  PERFORM csv_read.
ELSEIF P_CHKM = 'X'.
  CONCATENATE P_FROM P_MOVE INTO dir_from.
  CONCATENATE P_TO   P_MOVE INTO dir_to  .
  PERFORM move_dir.
ELSEIF P_CHKD = 'X'.
  CONCATENATE P_DDEL P_FDEL INTO del_dir.
  PERFORM delete_dir.
ENDIF.

*&---------------------------------------------------------------------*
*&---------------------------------------------------------------------*
FORM f4_file_open_dialog  CHANGING p_file.
  DATA: lv_dir       TYPE string,
        lv_filetable TYPE filetable,
        lv_line      TYPE LINE OF filetable,
        lv_rc        TYPE i.
  CALL METHOD cl_gui_frontend_services=>get_temp_directory
    CHANGING
      temp_dir = lv_dir.
  CALL METHOD cl_gui_frontend_services=>file_open_dialog
    EXPORTING
      window_title      = 'Choose file'
      initial_directory = lv_dir
      file_filter       = '*.xlsx'
      multiselection    = ' '
    CHANGING
      file_table        = lv_filetable
      rc                = lv_rc.
  IF lv_rc = 1.
    READ TABLE lv_filetable INDEX 1 INTO lv_line.
    p_file = lv_line-filename.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
FORM get_filename.
    CALL FUNCTION 'SO_SPLIT_FILE_AND_PATH'
            EXPORTING
             full_name           = p_file
           IMPORTING
             STRIPPED_NAME       = filename
*             FILE_PATH           =
           EXCEPTIONS
             X_ERROR             = 1
             OTHERS              = 2.

ENDFORM.
*&---------------------------------------------------------------------*
FORM csv_read .
  DATA : rawdata TYPE truxs_t_text_data,
         rawline LIKE LINE OF rawdata.

CALL FUNCTION 'GUI_UPLOAD'
    EXPORTING
      filename                      = p_file
      filetype                      = 'ASC'
      has_field_separator           = 'X'
*     HEADER_LENGTH                 = 0
*     READ_BY_LINE                  = 'X'
*     DAT_MODE                      = ' '
*     CODEPAGE                      = ' '
*     IGNORE_CERR                   = ABAP_TRUE
*     REPLACEMENT                   = '#'
*     CHECK_BOM                     = ' '
*     VIRUS_SCAN_PROFILE            =
*     NO_AUTH_CHECK                 = ' '
*   IMPORTING
*     FILELENGTH                    =
*     HEADER                        =
    TABLES
      data_tab                      = rawdata
*   CHANGING
*     ISSCANPERFORMED               = ' '
   EXCEPTIONS
     file_open_error               = 1
     file_read_error               = 2
     no_batch                      = 3
     gui_refuse_filetransfer       = 4
     invalid_type                  = 5
     no_authority                  = 6
     unknown_error                 = 7
     bad_data_format               = 8
     header_not_allowed            = 9
     separator_not_allowed         = 10
     header_too_long               = 11
     unknown_dp_error              = 12
     access_denied                 = 13
     dp_out_of_memory              = 14
     disk_full                     = 15
     dp_timeout                    = 16
     OTHERS                        = 17.
  IF sy-subrc <> 0.
    MESSAGE 'File failed to be read!' TYPE 'E'.
  ELSE.
    OPEN DATASET directory_uploaded_and_file FOR OUTPUT IN TEXT MODE ENCODING DEFAULT.
    IF sy-subrc = 0.
      LOOP AT rawdata INTO DATA(ls_raw).
        TRANSFER ls_raw TO directory_uploaded_and_file.
      ENDLOOP.
      MESSAGE 'File uploaded successfully!' TYPE 'S'.
    ELSE.
      MESSAGE 'File failed to upload!' TYPE 'E'.
    ENDIF.
    CLOSE DATASET directory_uploaded_and_file.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
FORM move_dir.
  DATA: lines TYPE STANDARD TABLE OF string,
        line TYPE string.

  OPEN DATASET dir_from FOR INPUT IN TEXT MODE ENCODING DEFAULT WITH SMART LINEFEED.
  IF sy-subrc = 0.
    DO.
      READ DATASET dir_from INTO line.
      IF sy-subrc <> 0.
        EXIT.
      ENDIF.
      APPEND line TO lines.
    ENDDO.
    CLOSE DATASET dir_from.
    CLEAR line.
    OPEN DATASET dir_to FOR OUTPUT IN TEXT MODE ENCODING DEFAULT.
    IF sy-subrc = 0.
      LOOP AT lines INTO line.
        TRANSFER line TO dir_to.
      ENDLOOP.
      MESSAGE 'File transported successfully to another directory!' TYPE 'S'.
    ELSE.
       MESSAGE 'File failed to upload in TO directory!' TYPE 'E'.
    ENDIF.
    CLOSE DATASET dir_to.
    DELETE DATASET dir_from.
  ELSE.
    MESSAGE 'File does not exist in said directory!' TYPE 'E'.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
FORM delete_dir.
*  OPEN DATASET del_dir FOR INPUT IN TEXT MODE ENCODING DEFAULT WITH SMART LINEFEED.
*  CLOSE DATASET del_dir.
  DELETE DATASET del_dir.
  IF sy-subrc = 0.
    MESSAGE 'File deleted successfully!' TYPE 'S'.
  ELSE.
    MESSAGE 'File could not be deleted!' TYPE 'E'.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
