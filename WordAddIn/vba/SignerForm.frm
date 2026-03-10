VERSION 5.00
Begin {C62A69F0-16DC-11CE-9E98-00AA00574A4F} SignerForm
   Caption         =   "Nintex eSign - Field Palette"
   ClientHeight    =   10200
   ClientLeft      =   120
   ClientTop       =   465
   ClientWidth     =   5400
   StartUpPosition =   1  'CenterOwner
   Begin {978C9E23-D4B0-11CE-BF2D-00AA003F40D0} lblHeader
      Caption         =   "SIGNERS"
      Height          =   240
      Left            =   180
      Top             =   60
      Width           =   3000
   End
   Begin {8BD21D20-EC42-11CE-9E0D-00AA006002F3} lstSigners
      Height          =   1200
      Left            =   180
      Top             =   360
      Width           =   5040
   End
   Begin {D7053240-CE69-11CD-A777-00DD01143C57} btnAddSigner
      Caption         =   "+ Add"
      Height          =   360
      Left            =   180
      Top             =   1620
      Width           =   960
   End
   Begin {D7053240-CE69-11CD-A777-00DD01143C57} btnEditSigner
      Caption         =   "Edit"
      Height          =   360
      Left            =   1200
      Top             =   1620
      Width           =   840
   End
   Begin {D7053240-CE69-11CD-A777-00DD01143C57} btnRemoveSigner
      Caption         =   "Remove"
      Height          =   360
      Left            =   2100
      Top             =   1620
      Width           =   960
   End
   Begin {978C9E23-D4B0-11CE-BF2D-00AA003F40D0} lblName
      Caption         =   "Full Name:"
      Height          =   240
      Left            =   180
      Top             =   2100
      Width           =   960
      Visible         =   0   'False
   End
   Begin {8BD21D10-EC42-11CE-9E0D-00AA006002F3} txtSignerName
      Height          =   300
      Left            =   1200
      Top             =   2100
      Width           =   3960
      Visible         =   0   'False
   End
   Begin {978C9E23-D4B0-11CE-BF2D-00AA003F40D0} lblEmail
      Caption         =   "Email:"
      Height          =   240
      Left            =   180
      Top             =   2460
      Width           =   960
      Visible         =   0   'False
   End
   Begin {8BD21D10-EC42-11CE-9E0D-00AA006002F3} txtSignerEmail
      Height          =   300
      Left            =   1200
      Top             =   2460
      Width           =   3960
      Visible         =   0   'False
   End
   Begin {978C9E23-D4B0-11CE-BF2D-00AA003F40D0} lblOrder
      Caption         =   "Order:"
      Height          =   240
      Left            =   180
      Top             =   2820
      Width           =   960
      Visible         =   0   'False
   End
   Begin {8BD21D10-EC42-11CE-9E0D-00AA006002F3} txtSignerOrder
      Height          =   300
      Left            =   1200
      Top             =   2820
      Width           =   720
      Visible         =   0   'False
   End
   Begin {D7053240-CE69-11CD-A777-00DD01143C57} btnSaveSigner
      Caption         =   "Save"
      Height          =   360
      Left            =   2880
      Top             =   3180
      Width           =   960
      Visible         =   0   'False
   End
   Begin {D7053240-CE69-11CD-A777-00DD01143C57} btnCancelSigner
      Caption         =   "Cancel"
      Height          =   360
      Left            =   3900
      Top             =   3180
      Width           =   960
      Visible         =   0   'False
   End
   Begin {978C9E23-D4B0-11CE-BF2D-00AA003F40D0} lblFields
      Caption         =   "FIELD PALETTE"
      Height          =   240
      Left            =   180
      Top             =   3660
      Width           =   3000
   End
   Begin {978C9E23-D4B0-11CE-BF2D-00AA003F40D0} lblAssign
      Caption         =   "Assign to:"
      Height          =   240
      Left            =   180
      Top             =   3960
      Width           =   840
   End
   Begin {8BD21D30-EC42-11CE-9E0D-00AA006002F3} cboFieldSigner
      Height          =   300
      Left            =   1080
      Top             =   3960
      Width           =   4140
   End
   Begin {D7053240-CE69-11CD-A777-00DD01143C57} btnField_jignature
      Caption         =   "Signature"
      Height          =   540
      Left            =   180
      Top             =   4380
      Width           =   1680
   End
   Begin {D7053240-CE69-11CD-A777-00DD01143C57} btnField_jignatureInitial
      Caption         =   "Initials"
      Height          =   540
      Left            =   1920
      Top             =   4380
      Width           =   1680
   End
   Begin {D7053240-CE69-11CD-A777-00DD01143C57} btnField_signingDate
      Caption         =   "Date Signed"
      Height          =   540
      Left            =   3660
      Top             =   4380
      Width           =   1680
   End
   Begin {D7053240-CE69-11CD-A777-00DD01143C57} btnField_signerName
      Caption         =   "Full Name"
      Height          =   540
      Left            =   180
      Top             =   4980
      Width           =   1680
   End
   Begin {D7053240-CE69-11CD-A777-00DD01143C57} btnField_signerEmail
      Caption         =   "Email"
      Height          =   540
      Left            =   1920
      Top             =   4980
      Width           =   1680
   End
   Begin {D7053240-CE69-11CD-A777-00DD01143C57} btnField_checkBox
      Caption         =   "Checkbox"
      Height          =   540
      Left            =   3660
      Top             =   4980
      Width           =   1680
   End
   Begin {D7053240-CE69-11CD-A777-00DD01143C57} btnField_textField
      Caption         =   "Text Input"
      Height          =   540
      Left            =   180
      Top             =   5580
      Width           =   1680
   End
   Begin {D7053240-CE69-11CD-A777-00DD01143C57} btnField_signerCompany
      Caption         =   "Company"
      Height          =   540
      Left            =   1920
      Top             =   5580
      Width           =   1680
   End
   Begin {D7053240-CE69-11CD-A777-00DD01143C57} btnField_signerTitle
      Caption         =   "Title"
      Height          =   540
      Left            =   3660
      Top             =   5580
      Width           =   1680
   End
   Begin {978C9E23-D4B0-11CE-BF2D-00AA003F40D0} lblPlaced
      Caption         =   "PLACED FIELDS"
      Height          =   240
      Left            =   180
      Top             =   6240
      Width           =   3000
   End
   Begin {8BD21D20-EC42-11CE-9E0D-00AA006002F3} lstPlaced
      Height          =   1200
      Left            =   180
      Top             =   6540
      Width           =   5040
   End
   Begin {D7053240-CE69-11CD-A777-00DD01143C57} btnRemoveField
      Caption         =   "Remove Selected"
      Height          =   360
      Left            =   180
      Top             =   7800
      Width           =   1560
   End
   Begin {D7053240-CE69-11CD-A777-00DD01143C57} btnClearAll
      Caption         =   "Clear All Fields"
      Height          =   360
      Left            =   1800
      Top             =   7800
      Width           =   1560
   End
   Begin {978C9E23-D4B0-11CE-BF2D-00AA003F40D0} lblStatus
      Caption         =   ""
      Height          =   240
      Left            =   180
      Top             =   8280
      Width           =   5040
   End
End
Attribute VB_Name = "SignerForm"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = False
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False

Option Explicit

Private editingIndex As Long

' ============================================================
'  Form Initialization
' ============================================================
Private Sub UserForm_Initialize()
    editingIndex = -1

    ' Initialize signers if not done
    If NintexESign.SignerCount = 0 Then
        NintexESign.InitSigners
    End If

    cboFieldSigner.Style = fmStyleDropDownList

    RefreshSignerList
    RefreshSignerDropdown
    RefreshPlacedList
    UpdateFieldButtonState
End Sub

' ============================================================
'  Signer Buttons
' ============================================================
Private Sub btnAddSigner_Click()
    editingIndex = -1
    ShowSignerInput True
    txtSignerName.Text = ""
    txtSignerEmail.Text = ""
    txtSignerOrder.Text = CStr(NintexESign.SignerCount + 1)
    txtSignerName.SetFocus
End Sub

Private Sub btnEditSigner_Click()
    If lstSigners.ListIndex < 0 Then
        MsgBox "Select a signer to edit.", vbInformation, "Nintex eSign"
        Exit Sub
    End If
    editingIndex = lstSigners.ListIndex + 1
    ShowSignerInput True
    txtSignerName.Text = NintexESign.Signers(editingIndex).FullName
    txtSignerEmail.Text = NintexESign.Signers(editingIndex).Email
    txtSignerOrder.Text = CStr(NintexESign.Signers(editingIndex).SigningOrder)
    txtSignerName.SetFocus
End Sub

Private Sub btnRemoveSigner_Click()
    If lstSigners.ListIndex < 0 Then
        MsgBox "Select a signer to remove.", vbInformation, "Nintex eSign"
        Exit Sub
    End If
    Dim idx As Long
    idx = lstSigners.ListIndex + 1
    If MsgBox("Remove signer " & Chr(34) & NintexESign.Signers(idx).FullName & Chr(34) & "?", vbYesNo + vbQuestion, "Nintex eSign") = vbYes Then
        NintexESign.RemoveSigner idx
        RefreshSignerList
        RefreshSignerDropdown
        UpdateFieldButtonState
    End If
End Sub

Private Sub btnSaveSigner_Click()
    Dim sName As String, sEmail As String, sOrder As Long
    sName = Trim(txtSignerName.Text)
    sEmail = Trim(txtSignerEmail.Text)
    sOrder = Val(txtSignerOrder.Text)
    If sOrder < 1 Then sOrder = 1

    If sName = "" Then
        MsgBox "Full name is required.", vbExclamation, "Nintex eSign"
        txtSignerName.SetFocus
        Exit Sub
    End If
    If sEmail = "" Then
        MsgBox "Email is required.", vbExclamation, "Nintex eSign"
        txtSignerEmail.SetFocus
        Exit Sub
    End If

    If editingIndex > 0 Then
        NintexESign.UpdateSigner editingIndex, sName, sEmail, sOrder
    Else
        NintexESign.AddSigner sName, sEmail, sOrder
    End If

    ShowSignerInput False
    editingIndex = -1
    RefreshSignerList
    RefreshSignerDropdown
    UpdateFieldButtonState
    ShowStatus "Signer saved: " & sName
End Sub

Private Sub btnCancelSigner_Click()
    ShowSignerInput False
    editingIndex = -1
End Sub

' ============================================================
'  Field Buttons
' ============================================================
Private Sub btnField_jignature_Click()
    InsertSelectedField NintexESign.FLD_SIGNATURE, "Signature"
End Sub
Private Sub btnField_jignatureInitial_Click()
    InsertSelectedField NintexESign.FLD_INITIAL, "Initials"
End Sub
Private Sub btnField_signingDate_Click()
    InsertSelectedField NintexESign.FLD_DATE, "Date Signed"
End Sub
Private Sub btnField_signerName_Click()
    InsertSelectedField NintexESign.FLD_FULLNAME, "Full Name"
End Sub
Private Sub btnField_signerEmail_Click()
    InsertSelectedField NintexESign.FLD_EMAIL, "Email"
End Sub
Private Sub btnField_checkBox_Click()
    InsertSelectedField NintexESign.FLD_CHECKBOX, "Checkbox"
End Sub
Private Sub btnField_textField_Click()
    InsertSelectedField NintexESign.FLD_TEXT, "Text Input"
End Sub
Private Sub btnField_signerCompany_Click()
    InsertSelectedField NintexESign.FLD_COMPANY, "Company"
End Sub
Private Sub btnField_signerTitle_Click()
    InsertSelectedField NintexESign.FLD_TITLE, "Title"
End Sub

Private Sub InsertSelectedField(fieldTag As String, fieldLabel As String)
    If cboFieldSigner.ListIndex < 0 Then
        MsgBox "Please select a signer first.", vbExclamation, "Nintex eSign"
        Exit Sub
    End If

    Dim signerIdx As Long
    signerIdx = cboFieldSigner.ListIndex + 1

    NintexESign.InsertField signerIdx, fieldTag, fieldLabel
    RefreshPlacedList
    ShowStatus fieldLabel & " inserted for " & NintexESign.Signers(signerIdx).FullName
End Sub

' ============================================================
'  Placed Field Buttons
' ============================================================
Private Sub btnRemoveField_Click()
    If lstPlaced.ListIndex < 0 Then
        MsgBox "Select a field to remove.", vbInformation, "Nintex eSign"
        Exit Sub
    End If

    Dim parts() As String
    parts = Split(lstPlaced.List(lstPlaced.ListIndex), " | ")
    If UBound(parts) >= 1 Then
        NintexESign.RemoveFieldByTag Trim(parts(UBound(parts)))
    End If
    RefreshPlacedList
    ShowStatus "Field removed."
End Sub

Private Sub btnClearAll_Click()
    If MsgBox("Remove all placed fields from the document?", vbYesNo + vbQuestion, "Nintex eSign") = vbYes Then
        NintexESign.ClearAllFields
        RefreshPlacedList
        ShowStatus "All fields cleared."
    End If
End Sub

Private Sub lstPlaced_DblClick(ByVal Cancel As MSForms.ReturnBoolean)
    If lstPlaced.ListIndex < 0 Then Exit Sub
    Dim parts() As String
    parts = Split(lstPlaced.List(lstPlaced.ListIndex), " | ")
    If UBound(parts) >= 1 Then
        NintexESign.SelectFieldByTag Trim(parts(UBound(parts)))
    End If
End Sub

' ============================================================
'  Helpers
' ============================================================
Private Sub ShowSignerInput(show As Boolean)
    lblName.Visible = show
    txtSignerName.Visible = show
    lblEmail.Visible = show
    txtSignerEmail.Visible = show
    lblOrder.Visible = show
    txtSignerOrder.Visible = show
    btnSaveSigner.Visible = show
    btnCancelSigner.Visible = show
End Sub

Private Sub RefreshSignerList()
    lstSigners.Clear
    Dim i As Long
    For i = 1 To NintexESign.SignerCount
        lstSigners.AddItem NintexESign.Signers(i).FullName & " <" & NintexESign.Signers(i).Email & "> (Order: " & NintexESign.Signers(i).SigningOrder & ")"
    Next i
End Sub

Private Sub RefreshSignerDropdown()
    Dim prevIdx As Long
    prevIdx = cboFieldSigner.ListIndex
    cboFieldSigner.Clear

    Dim i As Long
    For i = 1 To NintexESign.SignerCount
        cboFieldSigner.AddItem NintexESign.Signers(i).FullName & " <" & NintexESign.Signers(i).Email & ">"
    Next i

    If prevIdx >= 0 And prevIdx < cboFieldSigner.ListCount Then
        cboFieldSigner.ListIndex = prevIdx
    ElseIf cboFieldSigner.ListCount > 0 Then
        cboFieldSigner.ListIndex = 0
    End If
End Sub

Private Sub RefreshPlacedList()
    lstPlaced.Clear
    Dim cc As ContentControl
    For Each cc In ActiveDocument.ContentControls
        If Left(cc.Tag, 9) = "{{signer" Then
            lstPlaced.AddItem cc.Title & " | " & cc.Tag
        End If
    Next cc
End Sub

Private Sub UpdateFieldButtonState()
    Dim hasSigners As Boolean
    hasSigners = (NintexESign.SignerCount > 0)

    btnField_jignature.Enabled = hasSigners
    btnField_jignatureInitial.Enabled = hasSigners
    btnField_signingDate.Enabled = hasSigners
    btnField_signerName.Enabled = hasSigners
    btnField_signerEmail.Enabled = hasSigners
    btnField_checkBox.Enabled = hasSigners
    btnField_textField.Enabled = hasSigners
    btnField_signerCompany.Enabled = hasSigners
    btnField_signerTitle.Enabled = hasSigners
    cboFieldSigner.Enabled = hasSigners
End Sub

Private Sub ShowStatus(msg As String)
    lblStatus.Caption = msg
End Sub
