' Modul1

'Funktionsaufruf: =LastSavedDateTime()
Function LastSavedDateTime() As String
    LastSavedDateTime = "Stand: " + Format(ThisWorkbook.BuiltinDocumentProperties("Last Save Time"), "DD.MM.YY, HH:MM") + " Uhr"
End Function


'Funktionsaufruf: =LastAuthor()
Function LastAuthor() As String
    LastAuthor = "Zuletzt gespeichert durch: " + ThisWorkbook.BuiltinDocumentProperties("Last Author")
End Function



' ThisWorkbook
' beim speichen werden alle zellen aktualisiert und somit die funkionen auch neu aufgerufen
Private Sub Workbook_BeforeSave(ByVal SaveAsUI As Boolean, Cancel As Boolean)
    Dim ws As Worksheet
    For Each ws In ThisWorkbook.Sheets
       Application.CalculateFull
    Next ws
End Sub
