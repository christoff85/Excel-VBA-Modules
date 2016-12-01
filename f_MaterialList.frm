VERSION 5.00
Begin {C62A69F0-16DC-11CE-9E98-00AA00574A4F} f_MaterialList 
   Caption         =   "Edit the list of the Materials"
   ClientHeight    =   5385
   ClientLeft      =   45
   ClientTop       =   375
   ClientWidth     =   10815
   OleObjectBlob   =   "f_MaterialList.frx":0000
   ShowModal       =   0   'False
   StartUpPosition =   2  'CenterScreen
End
Attribute VB_Name = "f_MaterialList"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = False
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False

'---------------------------------------------------------------------------------------------------------
'   Maintains simple database located in the secure worksheet.
'   Database can be used as a source for Data Validation List
'
'   Written By Krzysztof Grzeslak 01/03/2016
'
'   Preconditions:
'   *   Form needs to be initialized with Excel Worksheet, that includes named Range "MaterialDatabase"
'       (name can be changed, but constant MAT_DATABASE_RNG also need to be changed).
'   *   List is single column.
'   *   Empty list must consist of two empty cell
'
'   Usage:
'   *   User can add new item to database (after or before currently selected item)
'   *   User can remove the item from the database
'   *   User can rename the item in the database
'   *   Form is representing state error, if user won't meet every precondition of chosen subprocedure
'   *   Database is secure (removing all the items won't compromise the named range
'---------------------------------------------------------------------------------------------------------

Option Explicit

' Name of the range in the secure worksheet
Const MAT_DATABASE_RNG As String = "MaterialDatabase"

' Form fields
Private x_matDatabase As Range
Private x_matListCurPos As Integer

' positions of the added materials
Private Enum e_insertMaterial
    e_insertMaterial_Before = -1
    e_insertMaterial_After = 1
    e_insertMaterial_FirstInBase = 1
End Enum

' State repors
Private Enum e_stateMsg
    e_stateMsg_noPosition
    e_stateMsg_noNameNew
    e_stateMsg_noNameCur
    e_stateMsg_noSelected
    e_stateMsg_matExist
    e_stateMsg_sameName
    e_stateMsg_success
End Enum

'Form initialization and ordinal procedures
Public Sub Initialize(setupWs As Worksheet)
    Const DEFAULT_LIST_POS = 0
    
    Call setMaterialDatabase(setupWs)
    Call setListCurPos(DEFAULT_LIST_POS)
    Call RefreshMaterialsForm
    Me.Show

End Sub

' Sets database range object to form field
Private Sub setMaterialDatabase(setupWs As Worksheet)
    
    Set x_matDatabase = setupWs.Range(MAT_DATABASE_RNG)

End Sub

' Retrieves database range object from the form field
Private Function getMaterialDatabase() As Range
    
    Set getMaterialDatabase = x_matDatabase

End Function

' Sets current highlighted position in the list to the form field
Private Sub setListCurPos(curPos As Integer)
       
    If curPos >= 0 Then
        x_matListCurPos = curPos
    End If

End Sub

' Retrieves current highlighted position in the list from the form field
Private Function getListCurPos() As Integer
       
    getListCurPos = x_matListCurPos

End Function

' Refreshes the database list in the form window
Private Sub RefreshMaterialsForm()

    Call clearForm
    Call populateMaterialList
    Call selectListPosition
    Call setFormState
    Call ReportState(e_stateMsg_success) ' returns empty message
    
End Sub

' Clears all the form controls
Private Sub clearForm()
    materialList.Clear
    addMaterialName.Value = vbNullString
    chgMaterialName.Value = vbNullString
    optionBefore.Value = False
    optionAfter.Value = False

End Sub

' Add all items from the named range to the form list control
Private Sub populateMaterialList()
    Dim materialCell As Range
    
    ' If cell is not empty, add it's value to the list
    For Each materialCell In getMaterialDatabase
        If materialCell.Value <> vbNullString Then
            materialList.AddItem materialCell.Value
        End If
    Next materialCell

End Sub

' Re-select last edited or added item
Private Sub selectListPosition()
    
    If Not isMaterialListEmpty Then
        Dim newPosition As Integer
        Dim lastPosition As Integer
        
        lastPosition = materialList.ListCount - 1
        If getListCurPos <= lastPosition Then
            newPosition = getListCurPos
        Else
            newPosition = lastPosition
        End If
        
        materialList.Selected(newPosition) = True
    End If
End Sub

' Deactivate before / after radio buttons, if database is empty
Private Sub setFormState()

    If isMaterialListEmpty Then
        chgMaterialName.Enabled = False
        ChangeName.Enabled = False
        RemoveMaterial.Enabled = False
        optionAfter.Enabled = False
        optionBefore.Enabled = False
    Else
        chgMaterialName.Enabled = True
        ChangeName.Enabled = True
        RemoveMaterial.Enabled = True
        optionAfter.Enabled = True
        optionBefore.Enabled = True
    End If
    
End Sub

'Form events main procedures

Private Sub AddMaterial_Click()
     
    ' New item has no name, report error
    If Not isNewMaterialHasName Then
        Call ReportState(e_stateMsg_noNameNew)
        Exit Sub
    End If
    
    ' New item has the same name as another item in database, report error
    If isMaterialExist(addMaterialName.Value) Then
        Call ReportState(e_stateMsg_matExist)
        Exit Sub
    End If
    
    If isMaterialListEmpty Then
        ' Add first item to the database
        Call addNewMaterial(getMaterialCell, e_insertMaterial_FirstInBase)
    Else
        ' No material was chose - report error
        If Not isMaterialChosen Then
            Call ReportState(e_stateMsg_noSelected)
            Exit Sub
        End If
        
        ' Determine new material position and add new item or report error if position was not specified
        If optionBefore Then
            Call addNewMaterial(getMaterialCell, e_insertMaterial_Before)
        ElseIf optionAfter Then
            Call addNewMaterial(getMaterialCell, e_insertMaterial_After)
            Call setListCurPos(materialList.ListIndex + 1) ' Ensure selection of the newly added item
        Else
            Call ReportState(e_stateMsg_noPosition)
            Exit Sub
        End If
    End If
    
    Call RefreshMaterialsForm

End Sub

Private Sub RemoveMaterial_Click()
    
    ' Remove item from the database or report error, if no item was selected
    If isMaterialChosen Then
        Call RemoveMaterialFromList(getMaterialCell)
        Call RefreshMaterialsForm
    Else
        Call ReportState(e_stateMsg_noSelected)
    End If

End Sub

Private Sub ChangeName_click()
    
    ' Ensure item selection
    If Not isMaterialChosen Then
        Call ReportState(e_stateMsg_noSelected)
        Exit Sub
    End If
    
    ' Ensure new name was specified
    If Not isNewNameForMaterial Then
        Call ReportState(e_stateMsg_noNameCur)
        Exit Sub
    End If
    
    ' Ensure new name is different than old name
    If Not isNameDifferent Then
        Call ReportState(e_stateMsg_sameName)
        Exit Sub
    End If
    
    ' Ensure item with new name does not already exist
    If isMaterialExist(chgMaterialName.Value) Then
        Call ReportState(e_stateMsg_matExist)
        Exit Sub
    End If
    
    ' Rename item in database
    getMaterialCell.Value = chgMaterialName.Value
    Call RefreshMaterialsForm


End Sub

Private Sub CloseForm_Click()

    Unload Me

End Sub

' Updates the current name in the rename textbox and current position indicator
Private Sub materialList_Change()

    chgMaterialName.Value = materialList.Value
    Call setListCurPos(materialList.ListIndex)

End Sub

'Form events subprocedures and functions

Private Sub addNewMaterial(materialCell As Range, position As e_insertMaterial)
    Const COLUMN_OFFSET As Integer = 0
    
    ' Add new row before or after the current item cell
    Select Case position
        Case e_insertMaterial_Before
            materialCell.EntireRow.Insert
        Case e_insertMaterial_After
            materialCell.Offset(e_insertMaterial_After, COLUMN_OFFSET).EntireRow.Insert
    End Select
    
    ' Insert new item name to created cell
    materialCell.Offset(position, COLUMN_OFFSET).Value = addMaterialName.Value
     
End Sub

' Returns Range Object containing the cell with specified material
Private Function getMaterialCell() As Range
    Const OFFSET_POS As Integer = 1
    
    If isMaterialListEmpty Then
        Set getMaterialCell = getMaterialDatabase.Cells(OFFSET_POS, OFFSET_POS)
    Else
        Set getMaterialCell = getMaterialDatabase.Find(materialList.Value, lookat:=xlWhole, MatchCase:=True)
    End If
    
End Function

Private Sub RemoveMaterialFromList(materialCell As Range)

    materialCell.EntireRow.delete

End Sub

' Report error message to the user
Private Sub ReportState(state As e_stateMsg)
    Dim caption As String
    
    Select Case state
        Case e_stateMsg_noPosition
            caption = "Please select the material position"
        
        Case e_stateMsg_noNameNew
            caption = "Please specify the name for new material"
        
        Case e_stateMsg_noNameCur
            caption = "Please specify new name for current material"
        
        Case e_stateMsg_noSelected
            caption = "Please select material in the list"
        
        Case e_stateMsg_matExist
            caption = "Material with this name already exist"
            
        Case e_stateMsg_sameName
            caption = "New name and old name must be different"
            
        Case e_stateMsg_success
            caption = vbNullString
    End Select
    
    StateMsg.caption = caption

End Sub

'Boolean tests for the form controls error checking

Private Function isMaterialListEmpty() As Boolean
    
    isMaterialListEmpty = False
    
    If materialList.ListCount = 0 Then
        isMaterialListEmpty = True
    End If

End Function

Private Function isMaterialChosen() As Boolean

    isMaterialChosen = False
    
    If materialList.Value <> "Null" Then
        isMaterialChosen = True
    End If

End Function

Private Function isNewMaterialHasName() As Boolean

    isNewMaterialHasName = False
    
    If addMaterialName.Value <> vbNullString Then
        isNewMaterialHasName = True
    End If

End Function

Private Function isNewNameForMaterial() As Boolean

    isNewNameForMaterial = False
    
    If chgMaterialName.Value <> vbNullString Then
        isNewNameForMaterial = True
    End If

End Function

Private Function isMaterialExist(name As String) As Boolean
    
    isMaterialExist = True
    
    ' look for the material in the database
    Dim tempMaterial As Range
    Set tempMaterial = getMaterialDatabase.Find(name, lookat:=xlWhole, MatchCase:=True)
    
    ' material does not exist
    If tempMaterial Is Nothing Then
        isMaterialExist = False
    End If
End Function

Private Function isNameDifferent() As Boolean
    
    isNameDifferent = True
    
    If materialList.Value = chgMaterialName.Value Then
        isNameDifferent = False
    End If

End Function
