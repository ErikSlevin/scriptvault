Attribute VB_Name = "Modul1"
' Datei: ZahlInWorten.vba
' Autor: [Autorname]
' Datum: [Aktuelles Datum]
' Lizenz: [Lizenzinformation]

' Globale Variablen für Zahlworte und Hilfsworte in Deutsch
Private Zahlworte(0 To 28) As String
Private Hilfsworte(1 To 4) As String

' Diese Funktion wandelt eine Zahl in Worten um und gibt das Ergebnis zurück.
Function InWorten(ByVal Zahl As String) As String
    ' Aufruf der Funktion zur Umwandlung von Zahlen in Wörter mit deutscher Sprache
    InWorten = ZahlInWorten(Zahl)
End Function

' Diese Funktion wandelt eine Zahl in Worten um und gibt das Ergebnis zurück.
Function ZahlInWorten(ByVal Zahl As String) As String

Dim Euro As String, Cent As String
Dim Ergebnis As String, Temp As String
Dim Dezimalstelle As Integer, Zähler As Integer
Dim Stelle(1 To 6) As String
Dim dZahl As Double
Dim Präfix As String, Suffix As String

' Definition der Platzhalter für die Zahlenskalen
Stelle(1) = ""
Stelle(2) = " Tausend "
Stelle(3) = " Millionen "
Stelle(4) = " Milliarden "
Stelle(5) = " Billionen "
Stelle(6) = " Die Mantisse ist nicht groß genug für diese Zahl "
Hilfsworte(1) = ">>>>> Fehler (Absolutbetrag > 999999999999999)! <<<<<"
Hilfsworte(2) = " (gerundet)"
Hilfsworte(3) = "Minus "
Hilfsworte(4) = "und"
Zahlworte(0) = "null"
Zahlworte(1) = "ein"
Zahlworte(2) = "zwei"
Zahlworte(3) = "drei"
Zahlworte(4) = "vier"
Zahlworte(5) = "fünf"
Zahlworte(6) = "sechs"
Zahlworte(7) = "sieben"
Zahlworte(8) = "acht"
Zahlworte(9) = "neun"
Zahlworte(10) = "zehn"
Zahlworte(11) = "elf"
Zahlworte(12) = "zwölf"
Zahlworte(13) = "dreizehn"
Zahlworte(14) = "vierzehn"
Zahlworte(15) = "fünfzehn"
Zahlworte(16) = "sechzehn"
Zahlworte(17) = "siebzehn"
Zahlworte(18) = "achtzehn"
Zahlworte(19) = "neunzehn"
Zahlworte(20) = "zwanzig"
Zahlworte(21) = "dreißig"
Zahlworte(22) = "vierzig"
Zahlworte(23) = "fünfzig"
Zahlworte(24) = "sechzig"
Zahlworte(25) = "siebzig"
Zahlworte(26) = "achtzig"
Zahlworte(27) = "neunzig"
Zahlworte(28) = "hundert"

' Wenn die Eingabe leer ist, wird sie auf "0" gesetzt
If "" = Zahl Then
    Zahl = "0"
End If
      
' Die Eingabe wird als Zahl interpretiert
dZahl = Zahl + 0#
      
' Überprüfen, ob die Zahl innerhalb des unterstützten Bereichs liegt
If Abs(dZahl) > 999999999999999# Then
    ZahlInWorten = Hilfsworte(1)
    Exit Function
End If

' Rundungsindikator, falls erforderlich
If Abs(dZahl - Round(dZahl, 2)) > 1E-16 Then
    dZahl = Round(dZahl, 2)
    Suffix = Hilfsworte(2)
End If

' Vorzeichen der Zahl bestimmen
If dZahl < 0# Then
    Präfix = Hilfsworte(3)
    dZahl = -dZahl
    Zahl = Right(Zahl, Len(Zahl) - 1)
End If

' Formatierung der Eingabe als String
Zahl = Trim(Str(Zahl))
If Left(Zahl, 1) = "." Then
    Zahl = "0" & Zahl
End If

' Position der Dezimalstelle ermitteln
Dezimalstelle = InStr(Zahl, ".")
        
' Wenn Dezimalstellen vorhanden sind, werden sie separat behandelt
If Dezimalstelle > 0 Then
    Cent = GetTens(Left(Mid(Zahl, Dezimalstelle + 1) & "00", 2))
    Zahl = Trim(Left(Zahl, Dezimalstelle - 1))
End If

Zähler = 1
Do While Zahl <> ""
    Temp = GetHundreds(Right(Zahl, 3))
    If Temp <> "" Then
        If Euro <> "" Then
            Euro = Temp & Stelle(Zähler) & " " & _
                   Hilfsworte(4) & " " & Euro
        Else
            Euro = Temp & Stelle(Zähler) & Euro
        End If
    End If
    If Len(Zahl) > 3 Then
        Zahl = Left(Zahl, Len(Zahl) - 3)
    Else
        Zahl = ""
    End If
    Zähler = Zähler + 1
Loop
  
' Währungsformatierung für Euro
Select Case Euro
    Case ""
        Euro = Zahlworte(0) & " Euro"
    Case Zahlworte(1)
        Euro = Zahlworte(1) & " Euro"
    Case Else
        Euro = Euro & " Euro"
End Select
  
' Wenn keine Cent vorhanden sind, wird ein Platzhalter eingesetzt
Select Case Cent
    Case ""
        Cent = " " & Hilfsworte(4) & " " & Zahlworte(0) & " Cent"
    Case Zahlworte(1)
        Cent = " " & Hilfsworte(4) & " " & Zahlworte(1) & " Cent"
    Case Else
        Cent = " " & Hilfsworte(4) & " " & Cent & " Cent"
End Select

' Ergebnis zusammenführen und formatieren
Temp = UCase(Replace(Euro & Cent, "  ", " "))
Temp = Application.WorksheetFunction.Proper(Temp)

' Sprachspezifische Anpassungen
Temp = Replace(Temp, " Ein ", " ein ")
Temp = Replace(Temp, " Cents", " Cent")
Temp = Replace(Temp, " Und ", " und ")
    
' Gesamtergebnis zurückgeben
ZahlInWorten = Präfix & Temp & Suffix

End Function

' Diese Funktion wandelt eine dreistellige Zahl in Worten um und gibt das Ergebnis zurück.
Private Function GetHundreds(ByVal Zahl) As String
Dim Ergebnis As String

If Val(Zahl) = 0 Then Exit Function
    Zahl = Right("000" & Zahl, 3)

    If Mid(Zahl, 1, 1) <> "0" Then
        Ergebnis = ZifferInWort(Mid(Zahl, 1, 1)) _
                & Zahlworte(28)
        If Mid(Zahl, 2, 2) <> "00" Then
            Ergebnis = Ergebnis & Hilfsworte(4)
        End If
    End If

    If Mid(Zahl, 2, 1) <> "0" Then
        Ergebnis = Ergebnis & GetTens(Mid(Zahl, 2))
    ElseIf Mid(Zahl, 3, 1) <> "0" Then
        Ergebnis = Ergebnis & ZifferInWort(Mid(Zahl, 3))
    End If

    GetHundreds = Ergebnis
End Function

' Diese Funktion wandelt eine zweistellige Zahl in Worten um und gibt das Ergebnis zurück.
Private Function GetTens(ByVal Zehner As String) As String
Dim Ergebnis As String

Ergebnis = ""
If Val(Left(Zehner, 1)) = 1 Then
    If Val(Zehner) > 9 And Val(Zehner) < 20 Then
        GetTens = Zahlworte(Val(Zehner))
    End If
    Exit Function
Else
    If Val(Left(Zehner, 1)) > 1 And _
        Val(Left(Zehner, 1)) < 10 Then
        Ergebnis = Zahlworte(18 + Val(Left(Zehner, 1)))
    Else
        Ergebnis = ZifferInWort(Right(Zehner, 1))
    End If
    If Right(Zehner, 1) <> "0" And Left(Zehner, 1) <> "0" Then
        Ergebnis = ZifferInWort(Right(Zehner, 1)) & _
                    Hilfsworte(4) & Ergebnis
    End If
End If
GetTens = Ergebnis
End Function

' Diese Funktion wandelt eine einzelne Ziffer in Worten um und gibt das Ergebnis zurück.
Private Function ZifferInWort(ByVal Ziffer As String) As String
    If Val(Ziffer) < 10 Then
        ZifferInWort = Zahlworte(Val(Ziffer))
    Else
        ZifferInWort = ""
    End If
End Function

