Attribute VB_Name = "NintexESign"
Option Explicit

' ============================================================
'  Nintex eSign - Field Palette for Word
'  Module: NintexESign
'  Single-module approach (no UserForm needed)
' ============================================================

#If Mac Then
    Private Declare PtrSafe Function systemCall Lib "libc.dylib" Alias "system" (ByVal command As String) As Long
#End If

' --- Signer storage (module-level) ---
Public Type SignerInfo
    FullName As String
    Email As String
    SigningOrder As Long
End Type

Public Signers() As SignerInfo
Public SignerCount As Long

' --- Field type constants ---
Public Const FLD_SIGNATURE As String = "jignature"
Public Const FLD_INITIAL As String = "jignatureInitial"
Public Const FLD_DATE As String = "signingDate"
Public Const FLD_FULLNAME As String = "signerName"
Public Const FLD_EMAIL As String = "signerEmail"
Public Const FLD_CHECKBOX As String = "checkBox"
Public Const FLD_TEXT As String = "textField"
Public Const FLD_COMPANY As String = "signerCompany"
Public Const FLD_TITLE As String = "signerTitle"

' --- Signer colors ---
Private Function GetSignerColor(signerIndex As Long) As Long
    Dim colors(0 To 5) As Long
    colors(0) = RGB(183, 28, 28)
    colors(1) = RGB(21, 101, 192)
    colors(2) = RGB(46, 125, 50)
    colors(3) = RGB(230, 81, 0)
    colors(4) = RGB(106, 27, 154)
    colors(5) = RGB(0, 131, 143)
    GetSignerColor = colors(signerIndex Mod 6)
End Function

' ============================================================
'  Ribbon Callback - Main Entry Point
' ============================================================
Public Sub OnOpenFieldPalette(control As IRibbonControl)
    ShowMainMenu
End Sub

' Also allow running directly from macros menu
Public Sub NintexFieldPalette()
    ShowMainMenu
End Sub

' ============================================================
'  Main Menu
' ============================================================
Private Sub ShowMainMenu()
    If SignerCount = 0 Then
        ReDim Signers(1 To 1)
    End If

    Dim choice As String
    Dim prompt As String

    Do
        prompt = "===== Nintex eSign Field Palette =====" & vbCrLf & vbCrLf
        prompt = prompt & "Signers: " & SignerCount & "    Fields placed: " & CountPlacedFields() & vbCrLf & vbCrLf
        prompt = prompt & "1 - Add Signer" & vbCrLf
        prompt = prompt & "2 - View/Edit Signers" & vbCrLf
        prompt = prompt & "3 - Insert Field at Cursor" & vbCrLf
        prompt = prompt & "4 - View Placed Fields" & vbCrLf
        prompt = prompt & "5 - Remove a Placed Field" & vbCrLf
        prompt = prompt & "6 - Clear All Fields" & vbCrLf & vbCrLf
        prompt = prompt & "--- eSign Portal ---" & vbCrLf
        prompt = prompt & "7 - Send Envelope (Portal)" & vbCrLf
        prompt = prompt & "8 - Create Template (Portal)" & vbCrLf
        prompt = prompt & "9 - Download Template (Portal)" & vbCrLf & vbCrLf
        prompt = prompt & "Enter a number (or Cancel to close):"

        choice = InputBox(prompt, "Nintex eSign")

        If choice = "" Then Exit Do

        Select Case Trim(choice)
            Case "1": MenuAddSigner
            Case "2": MenuViewSigners
            Case "3": MenuInsertField
            Case "4": MenuViewPlacedFields
            Case "5": MenuRemoveField
            Case "6": MenuClearAllFields
            Case "7": OpenPortalPage "/envelopes/?action=new"
            Case "8": OpenPortalPage "/templates/?action=new"
            Case "9": OpenPortalPage "/templates/"
            Case Else
                MsgBox "Invalid choice. Please enter 1-9.", vbExclamation, "Nintex eSign"
        End Select
    Loop
End Sub

' ============================================================
'  1 - Add Signer
' ============================================================
Private Sub MenuAddSigner()
    Dim sName As String
    sName = InputBox("Enter signer's full name:", "Nintex eSign - Add Signer")
    If sName = "" Then Exit Sub

    Dim sEmail As String
    sEmail = InputBox("Enter signer's email address:", "Nintex eSign - Add Signer", "")
    If sEmail = "" Then Exit Sub

    Dim sOrder As String
    sOrder = InputBox("Enter signing order (1, 2, 3...):", "Nintex eSign - Add Signer", CStr(SignerCount + 1))
    If sOrder = "" Then Exit Sub

    Dim orderNum As Long
    orderNum = Val(sOrder)
    If orderNum < 1 Then orderNum = SignerCount + 1

    SignerCount = SignerCount + 1
    ReDim Preserve Signers(1 To SignerCount)
    Signers(SignerCount).FullName = sName
    Signers(SignerCount).Email = sEmail
    Signers(SignerCount).SigningOrder = orderNum

    MsgBox "Signer added: " & sName & " <" & sEmail & ">" & vbCrLf & "Signing order: " & orderNum, vbInformation, "Nintex eSign"
End Sub

' ============================================================
'  2 - View/Edit Signers
' ============================================================
Private Sub MenuViewSigners()
    If SignerCount = 0 Then
        MsgBox "No signers added yet. Use option 1 to add a signer.", vbInformation, "Nintex eSign"
        Exit Sub
    End If

    Dim msg As String
    msg = "Current Signers:" & vbCrLf & vbCrLf

    Dim i As Long
    For i = 1 To SignerCount
        msg = msg & i & ". " & Signers(i).FullName & " <" & Signers(i).Email & ">" & vbCrLf
        msg = msg & "   Signing Order: " & Signers(i).SigningOrder & vbCrLf & vbCrLf
    Next i

    msg = msg & "Enter a signer number to edit/remove," & vbCrLf
    msg = msg & "or press Cancel to go back:"

    Dim choice As String
    choice = InputBox(msg, "Nintex eSign - Signers")
    If choice = "" Then Exit Sub

    Dim idx As Long
    idx = Val(choice)
    If idx < 1 Or idx > SignerCount Then
        MsgBox "Invalid signer number.", vbExclamation, "Nintex eSign"
        Exit Sub
    End If

    Dim action As VbMsgBoxResult
    action = MsgBox("Signer: " & Signers(idx).FullName & vbCrLf & vbCrLf & _
                     "Yes = Edit this signer" & vbCrLf & _
                     "No = Remove this signer" & vbCrLf & _
                     "Cancel = Go back", vbYesNoCancel + vbQuestion, "Nintex eSign")

    If action = vbYes Then
        Dim newName As String
        newName = InputBox("Full name:", "Edit Signer", Signers(idx).FullName)
        If newName = "" Then Exit Sub
        Dim newEmail As String
        newEmail = InputBox("Email:", "Edit Signer", Signers(idx).Email)
        If newEmail = "" Then Exit Sub
        Dim newOrder As String
        newOrder = InputBox("Signing order:", "Edit Signer", CStr(Signers(idx).SigningOrder))
        If newOrder = "" Then Exit Sub
        Signers(idx).FullName = newName
        Signers(idx).Email = newEmail
        Signers(idx).SigningOrder = Val(newOrder)
        MsgBox "Signer updated.", vbInformation, "Nintex eSign"
    ElseIf action = vbNo Then
        Dim j As Long
        For j = idx To SignerCount - 1
            Signers(j) = Signers(j + 1)
        Next j
        SignerCount = SignerCount - 1
        If SignerCount > 0 Then
            ReDim Preserve Signers(1 To SignerCount)
        End If
        MsgBox "Signer removed.", vbInformation, "Nintex eSign"
    End If
End Sub

' ============================================================
'  3 - Insert Field at Cursor
' ============================================================
Private Sub MenuInsertField()
    If SignerCount = 0 Then
        MsgBox "Add at least one signer first (option 1).", vbExclamation, "Nintex eSign"
        Exit Sub
    End If

    Dim signerPrompt As String
    signerPrompt = "Select a signer:" & vbCrLf & vbCrLf

    Dim i As Long
    For i = 1 To SignerCount
        signerPrompt = signerPrompt & i & ". " & Signers(i).FullName & " <" & Signers(i).Email & ">" & vbCrLf
    Next i

    signerPrompt = signerPrompt & vbCrLf & "Enter signer number:"

    Dim signerChoice As String
    signerChoice = InputBox(signerPrompt, "Nintex eSign - Insert Field")
    If signerChoice = "" Then Exit Sub

    Dim signerIdx As Long
    signerIdx = Val(signerChoice)
    If signerIdx < 1 Or signerIdx > SignerCount Then
        MsgBox "Invalid signer number.", vbExclamation, "Nintex eSign"
        Exit Sub
    End If

    Dim fieldPrompt As String
    fieldPrompt = "Insert field for: " & Signers(signerIdx).FullName & vbCrLf & vbCrLf
    fieldPrompt = fieldPrompt & "1 - Signature" & vbCrLf
    fieldPrompt = fieldPrompt & "2 - Initials" & vbCrLf
    fieldPrompt = fieldPrompt & "3 - Date Signed" & vbCrLf
    fieldPrompt = fieldPrompt & "4 - Full Name" & vbCrLf
    fieldPrompt = fieldPrompt & "5 - Email" & vbCrLf
    fieldPrompt = fieldPrompt & "6 - Checkbox" & vbCrLf
    fieldPrompt = fieldPrompt & "7 - Text Input" & vbCrLf
    fieldPrompt = fieldPrompt & "8 - Company" & vbCrLf
    fieldPrompt = fieldPrompt & "9 - Title" & vbCrLf & vbCrLf
    fieldPrompt = fieldPrompt & "Enter field number:"

    Dim fieldChoice As String
    fieldChoice = InputBox(fieldPrompt, "Nintex eSign - Insert Field")
    If fieldChoice = "" Then Exit Sub

    Dim fieldTag As String, fieldLabel As String
    Select Case Trim(fieldChoice)
        Case "1": fieldTag = FLD_SIGNATURE: fieldLabel = "Signature"
        Case "2": fieldTag = FLD_INITIAL: fieldLabel = "Initials"
        Case "3": fieldTag = FLD_DATE: fieldLabel = "Date Signed"
        Case "4": fieldTag = FLD_FULLNAME: fieldLabel = "Full Name"
        Case "5": fieldTag = FLD_EMAIL: fieldLabel = "Email"
        Case "6": fieldTag = FLD_CHECKBOX: fieldLabel = "Checkbox"
        Case "7": fieldTag = FLD_TEXT: fieldLabel = "Text Input"
        Case "8": fieldTag = FLD_COMPANY: fieldLabel = "Company"
        Case "9": fieldTag = FLD_TITLE: fieldLabel = "Title"
        Case Else
            MsgBox "Invalid field number.", vbExclamation, "Nintex eSign"
            Exit Sub
    End Select

    InsertField signerIdx, fieldTag, fieldLabel
    MsgBox fieldLabel & " field inserted for " & Signers(signerIdx).FullName & ".", vbInformation, "Nintex eSign"
End Sub

' ============================================================
'  4 - View Placed Fields
' ============================================================
Private Sub MenuViewPlacedFields()
    Dim count As Long
    count = 0
    Dim msg As String
    msg = "Placed Fields:" & vbCrLf & vbCrLf

    Dim cc As ContentControl
    For Each cc In ActiveDocument.ContentControls
        If Left(cc.Tag, 9) = "{{signer" Then
            count = count + 1
            msg = msg & count & ". " & cc.Title & vbCrLf
            msg = msg & "   Tag: " & cc.Tag & vbCrLf & vbCrLf
        End If
    Next cc

    If count = 0 Then
        MsgBox "No fields placed yet. Use option 3 to insert fields.", vbInformation, "Nintex eSign"
    Else
        MsgBox msg, vbInformation, "Nintex eSign"
    End If
End Sub

' ============================================================
'  5 - Remove a Placed Field
' ============================================================
Private Sub MenuRemoveField()
    Dim count As Long
    count = 0
    Dim msg As String
    msg = "Select a field to remove:" & vbCrLf & vbCrLf

    Dim cc As ContentControl
    Dim tags() As String
    ReDim tags(1 To ActiveDocument.ContentControls.count + 1)

    For Each cc In ActiveDocument.ContentControls
        If Left(cc.Tag, 9) = "{{signer" Then
            count = count + 1
            tags(count) = cc.Tag
            msg = msg & count & ". " & cc.Title & " [" & cc.Tag & "]" & vbCrLf
        End If
    Next cc

    If count = 0 Then
        MsgBox "No fields to remove.", vbInformation, "Nintex eSign"
        Exit Sub
    End If

    msg = msg & vbCrLf & "Enter field number to remove:"

    Dim choice As String
    choice = InputBox(msg, "Nintex eSign - Remove Field")
    If choice = "" Then Exit Sub

    Dim idx As Long
    idx = Val(choice)
    If idx < 1 Or idx > count Then
        MsgBox "Invalid field number.", vbExclamation, "Nintex eSign"
        Exit Sub
    End If

    For Each cc In ActiveDocument.ContentControls
        If cc.Tag = tags(idx) Then
            cc.Delete True
            MsgBox "Field removed.", vbInformation, "Nintex eSign"
            Exit Sub
        End If
    Next cc
End Sub

' ============================================================
'  6 - Clear All Fields
' ============================================================
Private Sub MenuClearAllFields()
    Dim count As Long
    count = CountPlacedFields()

    If count = 0 Then
        MsgBox "No fields to clear.", vbInformation, "Nintex eSign"
        Exit Sub
    End If

    If MsgBox("Remove all " & count & " placed field(s) from the document?", vbYesNo + vbQuestion, "Nintex eSign") = vbYes Then
        Dim i As Long
        Dim cc As ContentControl
        For i = ActiveDocument.ContentControls.count To 1 Step -1
            Set cc = ActiveDocument.ContentControls(i)
            If Left(cc.Tag, 9) = "{{signer" Then
                cc.Delete True
            End If
        Next i
        MsgBox "All fields cleared.", vbInformation, "Nintex eSign"
    End If
End Sub

' ============================================================
'  7/8/9 - Open eSign Portal Pages
' ============================================================
Private Sub OpenPortalPage(pagePath As String)
    Dim portalUrl As String
    portalUrl = GetSavedProperty("NintexPortalUrl")

    If portalUrl = "" Then
        portalUrl = InputBox("Enter your Nintex eSign Portal URL:" & vbCrLf & vbCrLf & _
                   "Example: https://e-sign-dev.powerappsportals.com" & vbCrLf & vbCrLf & _
                   "(This will be saved for future use)", "Nintex eSign - Portal URL")
        If portalUrl = "" Then Exit Sub

        ' Remove trailing slash
        If Right(portalUrl, 1) = "/" Then portalUrl = Left(portalUrl, Len(portalUrl) - 1)
        SaveDocProperty "NintexPortalUrl", portalUrl
    End If

    Dim fullUrl As String
    fullUrl = portalUrl & pagePath

    ' Open in default browser
    #If Mac Then
        systemCall "open '" & fullUrl & "'"
    #Else
        Shell "cmd /c start """" """ & fullUrl & """", vbHide
    #End If
End Sub

' ============================================================
'  Submit to Nintex eSign (kept for future direct API integration)
' ============================================================
Private Sub MenuSubmitToNintex()
    ' --- Validate ---
    If SignerCount = 0 Then
        MsgBox "Add at least one signer before submitting.", vbExclamation, "Nintex eSign"
        Exit Sub
    End If
    If CountPlacedFields() = 0 Then
        MsgBox "Place at least one field before submitting.", vbExclamation, "Nintex eSign"
        Exit Sub
    End If
    If ActiveDocument.Path = "" Then
        MsgBox "Please save the document first.", vbExclamation, "Nintex eSign"
        Exit Sub
    End If

    ' --- Envelope name ---
    Dim envName As String
    envName = InputBox("Enter envelope name:", "Nintex eSign - Submit", _
              Replace(ActiveDocument.Name, ".docx", "") & " - " & Format(Now, "yyyy-mm-dd"))
    If envName = "" Then Exit Sub

    ' --- Flow URL (saved in document property) ---
    Dim flowUrl As String
    flowUrl = GetSavedProperty("NintexFlowUrl")
    flowUrl = InputBox("Enter the Power Automate HTTP trigger URL:" & vbCrLf & vbCrLf & _
              "(This will be saved for future use)", "Nintex eSign - Submit", flowUrl)
    If flowUrl = "" Then Exit Sub
    SaveDocProperty "NintexFlowUrl", flowUrl

    ' --- Confirm ---
    Dim confirmMsg As String
    confirmMsg = "Ready to submit to Nintex eSign:" & vbCrLf & vbCrLf
    confirmMsg = confirmMsg & "Envelope: " & envName & vbCrLf
    confirmMsg = confirmMsg & "Signers: " & SignerCount & vbCrLf
    confirmMsg = confirmMsg & "Fields: " & CountPlacedFields() & vbCrLf & vbCrLf
    confirmMsg = confirmMsg & "The document will be converted with JotBlock tags" & vbCrLf
    confirmMsg = confirmMsg & "and sent to your Power Automate flow." & vbCrLf & vbCrLf
    confirmMsg = confirmMsg & "Continue?"
    If MsgBox(confirmMsg, vbYesNo + vbQuestion, "Nintex eSign") <> vbYes Then Exit Sub

    ' --- Save current document ---
    ActiveDocument.Save

    ' --- Create temp copy ---
    Dim tempPath As String
    #If Mac Then
        tempPath = "/tmp/NintexESign_submit_" & Format(Now, "yyyymmddhhnnss") & ".docx"
    #Else
        tempPath = Environ("TEMP") & "\NintexESign_submit_" & Format(Now, "yyyymmddhhnnss") & ".docx"
    #End If

    FileCopy ActiveDocument.FullName, tempPath

    ' --- Open temp copy and replace content controls with JotBlock tags ---
    Application.ScreenUpdating = False
    Dim tempDoc As Document
    Set tempDoc = Documents.Open(tempPath, ReadOnly:=False, Visible:=False)

    Dim cc As ContentControl
    Dim i As Long
    For i = tempDoc.ContentControls.count To 1 Step -1
        Set cc = tempDoc.ContentControls(i)
        If Left(cc.Tag, 9) = "{{signer" Then
            Dim jotTag As String
            jotTag = BuildJotBlockTag(cc.Tag)
            Dim rng As Range
            Set rng = cc.Range
            cc.Delete False  ' Delete control, keep text
            rng.Text = jotTag
        End If
    Next i

    tempDoc.Save
    tempDoc.Close SaveChanges:=False
    Application.ScreenUpdating = True

    ' --- Base64 encode the temp file ---
    Dim base64Doc As String
    base64Doc = FileToBase64(tempPath)

    If base64Doc = "" Then
        MsgBox "Failed to encode document.", vbCritical, "Nintex eSign"
        Kill tempPath
        Exit Sub
    End If

    ' --- Build JSON payload ---
    Dim jsonPayload As String
    jsonPayload = BuildSubmitJSON(envName, base64Doc, ActiveDocument.Name)

    ' --- Write payload to temp file (too large for inline) ---
    Dim payloadPath As String
    #If Mac Then
        payloadPath = "/tmp/NintexESign_payload.json"
    #Else
        payloadPath = Environ("TEMP") & "\NintexESign_payload.json"
    #End If

    Dim f As Integer
    f = FreeFile
    Open payloadPath For Output As #f
    Print #f, jsonPayload
    Close #f

    ' --- Send HTTP POST ---
    Dim responsePath As String
    #If Mac Then
        responsePath = "/tmp/NintexESign_response.json"
    #Else
        responsePath = Environ("TEMP") & "\NintexESign_response.json"
    #End If

    Dim httpResult As Boolean
    httpResult = HttpPostFromFile(flowUrl, payloadPath, responsePath)

    ' --- Read response ---
    Dim responseText As String
    responseText = ReadTextFile(responsePath)

    ' --- Cleanup temp files ---
    On Error Resume Next
    Kill tempPath
    Kill payloadPath
    Kill responsePath
    On Error GoTo 0

    ' --- Show result ---
    If httpResult And responseText <> "" Then
        MsgBox "Submitted successfully!" & vbCrLf & vbCrLf & _
               "Response:" & vbCrLf & Left(responseText, 500), vbInformation, "Nintex eSign"
    ElseIf httpResult Then
        MsgBox "Submitted successfully! (No response body)", vbInformation, "Nintex eSign"
    Else
        MsgBox "Submission may have failed." & vbCrLf & vbCrLf & _
               "Response:" & vbCrLf & Left(responseText, 500), vbExclamation, "Nintex eSign"
    End If
End Sub

' ============================================================
'  JotBlock Tag Builder
'  Converts content control tags to Nintex dynamic JotBlock syntax
'  Ref: https://help.nintex.com/en-US/assuresign/SimpleSetupEnvelope/DynamicJotblocks/JotblockSyntax.htm
' ============================================================
Private Function BuildJotBlockTag(ccTag As String) As String
    ' Parse tag: {{signer1_jignature}} -> signerIndex=1, fieldType="jignature"
    Dim inner As String
    inner = Mid(ccTag, 3, Len(ccTag) - 4) ' Remove {{ and }}

    Dim parts() As String
    parts = Split(inner, "_", 2)
    If UBound(parts) < 1 Then
        BuildJotBlockTag = ccTag
        Exit Function
    End If

    Dim signerIdx As Long
    signerIdx = Val(Mid(parts(0), 7)) ' "signer1" -> 1

    Dim fieldType As String
    fieldType = parts(1)

    Dim signerEmail As String
    signerEmail = ""
    If signerIdx >= 1 And signerIdx <= SignerCount Then
        signerEmail = Signers(signerIdx).Email
    End If

    ' Determine signing step (0-based) from signing order
    Dim signingStep As Long
    signingStep = 0
    If signerIdx >= 1 And signerIdx <= SignerCount Then
        signingStep = Signers(signerIdx).SigningOrder - 1
        If signingStep < 0 Then signingStep = 0
    End If

    Dim Q As String
    Q = Chr(34) ' double quote for JotBlock syntax

    Dim jb As String
    Select Case fieldType
        Case "jignature"
            jb = "{{!##{" & _
                 "Name:" & Q & inner & Q & "," & _
                 "InputType:" & Q & "Signatory" & Q & "," & _
                 "FieldType:" & Q & "Written" & Q & "," & _
                 "SignatoryEmail:" & Q & signerEmail & Q & "," & _
                 "SigningStep:" & signingStep & "," & _
                 "Height:0.05,Width:0.25," & _
                 "Border:" & Q & "All" & Q & "," & _
                 "InkColor:" & Q & "Blue" & Q & "," & _
                 "Required:true" & _
                 "}##!}}"

        Case "jignatureInitial"
            jb = "{{!##{" & _
                 "Name:" & Q & inner & Q & "," & _
                 "InputType:" & Q & "Signatory" & Q & "," & _
                 "FieldType:" & Q & "Written" & Q & "," & _
                 "SignatoryEmail:" & Q & signerEmail & Q & "," & _
                 "SigningStep:" & signingStep & "," & _
                 "Height:0.03,Width:0.08," & _
                 "Border:" & Q & "All" & Q & "," & _
                 "InkColor:" & Q & "Blue" & Q & "," & _
                 "Required:true" & _
                 "}##!}}"

        Case "signingDate"
            jb = "{{!##{" & _
                 "Name:" & Q & inner & Q & "," & _
                 "InputType:" & Q & "Signatory" & Q & "," & _
                 "FieldType:" & Q & "Typed" & Q & "," & _
                 "SignatoryEmail:" & Q & signerEmail & Q & "," & _
                 "SigningStep:" & signingStep & "," & _
                 "ValidationType:" & Q & "Date_CurrentDatePrefill" & Q & "," & _
                 "Height:0.02,Width:0.15," & _
                 "Required:true" & _
                 "}##!}}"

        Case "signerName"
            jb = "{{!##{" & _
                 "Name:" & Q & inner & Q & "," & _
                 "InputType:" & Q & "Signatory" & Q & "," & _
                 "FieldType:" & Q & "Typed" & Q & "," & _
                 "SignatoryEmail:" & Q & signerEmail & Q & "," & _
                 "SigningStep:" & signingStep & "," & _
                 "ValidationType:" & Q & "Alphanumeric_FullNamePrefill" & Q & "," & _
                 "Height:0.02,Width:0.20," & _
                 "Required:true" & _
                 "}##!}}"

        Case "signerEmail"
            jb = "{{!##{" & _
                 "Name:" & Q & inner & Q & "," & _
                 "InputType:" & Q & "Signatory" & Q & "," & _
                 "FieldType:" & Q & "Typed" & Q & "," & _
                 "SignatoryEmail:" & Q & signerEmail & Q & "," & _
                 "SigningStep:" & signingStep & "," & _
                 "ValidationType:" & Q & "Alphanumeric_EmailPrefill" & Q & "," & _
                 "Height:0.02,Width:0.20," & _
                 "Required:true" & _
                 "}##!}}"

        Case "checkBox"
            jb = "{{!##{" & _
                 "Name:" & Q & inner & Q & "," & _
                 "InputType:" & Q & "Signatory" & Q & "," & _
                 "FieldType:" & Q & "Typed" & Q & "," & _
                 "SignatoryInputType:" & Q & "MultipleChoiceCheckbox" & Q & "," & _
                 "SignatoryEmail:" & Q & signerEmail & Q & "," & _
                 "SigningStep:" & signingStep & "," & _
                 "Height:0.02,Width:0.02" & _
                 "}##!}}"

        Case "textField"
            jb = "{{!##{" & _
                 "Name:" & Q & inner & Q & "," & _
                 "InputType:" & Q & "Signatory" & Q & "," & _
                 "FieldType:" & Q & "Typed" & Q & "," & _
                 "SignatoryInputType:" & Q & "FreeText" & Q & "," & _
                 "SignatoryEmail:" & Q & signerEmail & Q & "," & _
                 "SigningStep:" & signingStep & "," & _
                 "Height:0.02,Width:0.20," & _
                 "Required:false" & _
                 "}##!}}"

        Case "signerCompany"
            jb = "{{!##{" & _
                 "Name:" & Q & inner & Q & "," & _
                 "InputType:" & Q & "Signatory" & Q & "," & _
                 "FieldType:" & Q & "Typed" & Q & "," & _
                 "SignatoryInputType:" & Q & "FreeText" & Q & "," & _
                 "SignatoryEmail:" & Q & signerEmail & Q & "," & _
                 "SigningStep:" & signingStep & "," & _
                 "Instructions:" & Q & "Company Name" & Q & "," & _
                 "Height:0.02,Width:0.20," & _
                 "Required:false" & _
                 "}##!}}"

        Case "signerTitle"
            jb = "{{!##{" & _
                 "Name:" & Q & inner & Q & "," & _
                 "InputType:" & Q & "Signatory" & Q & "," & _
                 "FieldType:" & Q & "Typed" & Q & "," & _
                 "SignatoryInputType:" & Q & "FreeText" & Q & "," & _
                 "SignatoryEmail:" & Q & signerEmail & Q & "," & _
                 "SigningStep:" & signingStep & "," & _
                 "Instructions:" & Q & "Job Title" & Q & "," & _
                 "Height:0.02,Width:0.15," & _
                 "Required:false" & _
                 "}##!}}"

        Case Else
            jb = ccTag
    End Select

    BuildJotBlockTag = jb
End Function

' ============================================================
'  JSON Payload Builder
' ============================================================
Private Function BuildSubmitJSON(envName As String, base64Doc As String, docName As String) As String
    Dim Q As String
    Q = Chr(34)

    Dim json As String
    json = "{" & vbCrLf

    ' Document
    json = json & Q & "documentBase64" & Q & ":" & Q & base64Doc & Q & "," & vbCrLf
    json = json & Q & "documentName" & Q & ":" & Q & EscapeJSON(docName) & Q & "," & vbCrLf
    json = json & Q & "envelopeName" & Q & ":" & Q & EscapeJSON(envName) & Q & "," & vbCrLf
    json = json & Q & "parseDocument" & Q & ":true," & vbCrLf

    ' Signers array
    json = json & Q & "signers" & Q & ":[" & vbCrLf
    Dim i As Long
    For i = 1 To SignerCount
        If i > 1 Then json = json & "," & vbCrLf
        json = json & "  {"
        json = json & Q & "name" & Q & ":" & Q & EscapeJSON(Signers(i).FullName) & Q & ","
        json = json & Q & "email" & Q & ":" & Q & EscapeJSON(Signers(i).Email) & Q & ","
        json = json & Q & "signingOrder" & Q & ":" & Signers(i).SigningOrder
        json = json & "}"
    Next i
    json = json & vbCrLf & "]" & vbCrLf

    json = json & "}"

    BuildSubmitJSON = json
End Function

' ============================================================
'  Base64 Encoding (Pure VBA - cross-platform)
' ============================================================
Private Function FileToBase64(filePath As String) As String
    On Error GoTo ErrHandler
    Dim f As Integer
    Dim fileData() As Byte

    f = FreeFile
    Open filePath For Binary Access Read As #f
    If LOF(f) = 0 Then
        Close #f
        FileToBase64 = ""
        Exit Function
    End If
    ReDim fileData(0 To LOF(f) - 1)
    Get #f, , fileData
    Close #f

    FileToBase64 = EncodeBase64(fileData)
    Exit Function

ErrHandler:
    FileToBase64 = ""
End Function

Private Function EncodeBase64(data() As Byte) As String
    Dim b64Chars As String
    b64Chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

    Dim dataLen As Long
    dataLen = UBound(data) - LBound(data) + 1

    ' Pre-allocate result (4 chars per 3 bytes, rounded up)
    Dim resultLen As Long
    resultLen = ((dataLen + 2) \ 3) * 4

    Dim result() As Byte
    ReDim result(0 To resultLen - 1)

    Dim i As Long, j As Long
    Dim b1 As Long, b2 As Long, b3 As Long
    Dim outIdx As Long
    outIdx = 0

    For i = LBound(data) To UBound(data) Step 3
        b1 = data(i)
        If i + 1 <= UBound(data) Then b2 = data(i + 1) Else b2 = 0
        If i + 2 <= UBound(data) Then b3 = data(i + 2) Else b3 = 0

        result(outIdx) = Asc(Mid(b64Chars, (b1 \ 4) + 1, 1))
        result(outIdx + 1) = Asc(Mid(b64Chars, ((b1 And 3) * 16 + b2 \ 16) + 1, 1))

        If i + 1 <= UBound(data) Then
            result(outIdx + 2) = Asc(Mid(b64Chars, ((b2 And 15) * 4 + b3 \ 64) + 1, 1))
        Else
            result(outIdx + 2) = 61 ' "="
        End If

        If i + 2 <= UBound(data) Then
            result(outIdx + 3) = Asc(Mid(b64Chars, (b3 And 63) + 1, 1))
        Else
            result(outIdx + 3) = 61 ' "="
        End If

        outIdx = outIdx + 4
    Next i

    ' Convert byte array to string
    Dim s As String
    s = ""
    Dim chunk As Long
    chunk = 0
    Dim tempStr As String
    tempStr = Space(resultLen)
    For i = 0 To resultLen - 1
        Mid(tempStr, i + 1, 1) = Chr(result(i))
    Next i

    EncodeBase64 = tempStr
End Function

' ============================================================
'  HTTP POST (Platform-specific)
' ============================================================
Private Function HttpPostFromFile(url As String, jsonFilePath As String, responsePath As String) As Boolean
    On Error GoTo ErrHandler

    #If Mac Then
        ' macOS: use curl via libc system() call
        Dim cmd As String
        cmd = "curl -s -X POST" & _
              " -H 'Content-Type: application/json'" & _
              " -d @'" & jsonFilePath & "'" & _
              " '" & url & "'" & _
              " -o '" & responsePath & "'" & _
              " -w '%{http_code}' > '" & responsePath & ".code' 2>/dev/null"
        systemCall cmd

        ' Check HTTP status code
        Dim statusCode As String
        statusCode = ReadTextFile(responsePath & ".code")
        On Error Resume Next
        Kill responsePath & ".code"
        On Error GoTo ErrHandler

        Dim code As Long
        code = Val(statusCode)
        HttpPostFromFile = (code >= 200 And code < 300)
    #Else
        ' Windows: use MSXML2.XMLHTTP
        Dim jsonContent As String
        jsonContent = ReadTextFile(jsonFilePath)

        Dim xhr As Object
        Set xhr = CreateObject("MSXML2.XMLHTTP")
        xhr.Open "POST", url, False
        xhr.setRequestHeader "Content-Type", "application/json"
        xhr.send jsonContent

        ' Write response to file
        Dim f As Integer
        f = FreeFile
        Open responsePath For Output As #f
        Print #f, xhr.responseText
        Close #f

        HttpPostFromFile = (xhr.Status >= 200 And xhr.Status < 300)
    #End If

    Exit Function
ErrHandler:
    HttpPostFromFile = False
End Function

' ============================================================
'  Document Property Helpers (persist flow URL)
' ============================================================
Private Function GetSavedProperty(propName As String) As String
    On Error Resume Next
    GetSavedProperty = ActiveDocument.CustomDocumentProperties(propName).Value
    On Error GoTo 0
End Function

Private Sub SaveDocProperty(propName As String, propValue As String)
    On Error Resume Next
    ActiveDocument.CustomDocumentProperties(propName).Delete
    On Error GoTo 0
    ActiveDocument.CustomDocumentProperties.Add propName, False, msoPropertyTypeString, propValue
End Sub

' ============================================================
'  String/File Utilities
' ============================================================
Private Function EscapeJSON(s As String) As String
    Dim result As String
    result = Replace(s, "\", "\\")
    result = Replace(result, Chr(34), "\" & Chr(34))
    result = Replace(result, vbCr, "\r")
    result = Replace(result, vbLf, "\n")
    result = Replace(result, vbTab, "\t")
    EscapeJSON = result
End Function

Private Function ReadTextFile(filePath As String) As String
    On Error GoTo ErrHandler
    Dim f As Integer
    Dim content As String

    If Dir(filePath) = "" Then
        ReadTextFile = ""
        Exit Function
    End If

    f = FreeFile
    Open filePath For Input As #f
    If LOF(f) > 0 Then
        content = Input(LOF(f), #f)
    End If
    Close #f

    ReadTextFile = content
    Exit Function

ErrHandler:
    ReadTextFile = ""
End Function

' ============================================================
'  Field Insertion
' ============================================================
Public Sub InsertField(signerIndex As Long, fieldTag As String, fieldLabel As String)
    If signerIndex < 1 Or signerIndex > SignerCount Then
        MsgBox "Invalid signer.", vbExclamation, "Nintex eSign"
        Exit Sub
    End If

    Dim signer As SignerInfo
    signer = Signers(signerIndex)

    Dim tagValue As String
    tagValue = "{{signer" & signerIndex & "_" & fieldTag & "}}"

    Dim firstName As String
    firstName = Split(signer.FullName, " ")(0)

    Dim placeholderText As String
    placeholderText = "[" & firstName & ": " & UCase(fieldLabel) & "]"

    Dim rng As Range
    Set rng = Selection.Range

    Dim cc As ContentControl
    Set cc = ActiveDocument.ContentControls.Add(wdContentControlRichText, rng)

    With cc
        .Tag = tagValue
        .Title = fieldLabel & " - " & signer.FullName
        .Range.Text = placeholderText
        .Range.Font.Bold = True
        .Range.Font.Size = 10
        .Range.Font.Color = GetSignerColor(signerIndex - 1)
    End With

    Selection.MoveRight wdCharacter, 1
End Sub

' ============================================================
'  Utilities
' ============================================================
Public Function CountPlacedFields() As Long
    Dim c As Long
    Dim cc As ContentControl
    c = 0
    For Each cc In ActiveDocument.ContentControls
        If Left(cc.Tag, 9) = "{{signer" Then
            c = c + 1
        End If
    Next cc
    CountPlacedFields = c
End Function
