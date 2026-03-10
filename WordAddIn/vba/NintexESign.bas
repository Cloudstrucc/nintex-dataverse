Attribute VB_Name = "NintexESign"
Option Explicit

' ============================================================
'  Nintex eSign - Field Palette for Word
'  Module: NintexESign
'  Single-module approach (no UserForm needed)
' ============================================================

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
            Case Else
                MsgBox "Invalid choice. Please enter 1-6.", vbExclamation, "Nintex eSign"
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
        ' Edit
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
        ' Remove
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

    ' Pick signer
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

    ' Pick field type
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

    ' Build list of Nintex content controls
    Dim cc As ContentControl
    Dim tags() As String
    ReDim tags(1 To ActiveDocument.ContentControls.count)

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

    ' Find and delete the content control with matching tag
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
