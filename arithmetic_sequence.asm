; Tomasz Podlaszewski

; OPIS WYKORZYSTANIA REJESTRÓW:
; rdi - początkowo: wskaźnik na tablicę A0 (arg 1). Przeniesiony do r9.
;       Następnie: wskaźnik na docelową tablicę Ak.
; rsi - wskaźnik na tablicę A1.
; rdx - Następnie: górne 64 bity mnożenia / górna część zwrotu int128_t.
; rcx - początkowo: rozmiar tablic n (arg 4). W pętli odlicza w dół.
;       Po pętli: przechowuje prawdziwy znak różnicy D i dolną połowę korekty k.
; r8  - wartość stałej k. Niezmienna przez cały algorytm.
;
; r9  - wskaźnik na tablicę A0 (przeniesiony z rdi). W pętli przesuwany ręcznie.
; rax - akumulator (mul, dodawania) / dolna część zwrotu int128_t.
; r10 - bufor na flagę CF z końcowego dodawania bazy A0. Po pętli: maska znaku.
; r11 - bufor na flagę CF (Borrow) z łańcucha odejmowania A1 - A0.
;
; REJESTRY STANU I BUFORY (Callee-saved / Chronione na stosie push/pop):
; rbx - bufor na resztę z mnożenia, przenoszone do kolejnej iteracji.
; rbp - rejestr roboczy (kopia zapasowa D[i], maski rozszerzeń znaku).

global arithmetic_sequence

section .text

arithmetic_sequence:
        ; Przeniesienie początkowego wskaźnika Ak do r9.
        mov     r9, rdx

        ; Wrzucenie na stos rejestrów callee-saved
        push    rbx             ; Bufor na resztę z mnożenia (Mult_Carry).
        push    rbp             ; Bufor roboczy (D[i] / rozszerzenia znaku).

        ; Inicjalizacja liczników i flag (zerowanie xorem z sobą).
        xor     r10, r10        ; Add_CF = 0
        xor     r11, r11        ; Sub_CF = 0
        ; Mult_Carry = 0 (32-bitowy xor automatycznie czyści całe rbx).
        xor     ebx, ebx

.main_loop:
        ; Dla skrótu różnicę obliczoną w i-tym przejściu oznaczam D[i].
        mov     rax, [rsi]      ; rax = A1[i]
        shr     r11, 1          ; Przerzucenie zapisanej flagi z r11 do CF.
        sbb     rax, [rdi]      ; rax = A1[i] - A0[i] - CF
        sbb     r11, r11        ; Zapisanie nowej flagi z odejmowania do r11.

        mov     rbp, rax        ; Zabezpieczenie D[i] przed mul.

        mul     r8              ; rdx:rax = D[i] * k

        ; Korekta dla ujemnego k (bo robimy mnożenie bez znaku, czyli
        ; dla ujemnego k mamy za duży wynik).
        test    r8, r8          ; Ustawia SF jeśli r8 jest ujemne.
        jns     .skip_k_corr    ; Skaczemy jeśli r8 dodatnie.
        ; Jeśli k < 0, odjęcie D[i] od górnej połowy mnozenia.
        sub     rdx, rbp
.skip_k_corr:

        ; Sklejanie reszty z mnożenia z poprzedniego przejścia pętli.
        ; Robimy ze starego przeniesienia, które jest rbx liczbę 128 bitową.
        mov     rbp, rbx
        sar     rbp, 63         ; rbp = rozszerzenie znaku starego rbx
        add     rax, rbx
        adc     rdx, rbp        ; Dodanie górnej połowy ze znakiem.
        mov     rbx, rdx        ; Nowe Mult_Carry jest w rbx.

        ; Dodawanie bazy A0 (Ak = A0 + D*k).
        shr     r10, 1          ; Odtworzenie starego Add_CF.
        adc     rax, [rdi]
        ; Zapisanie nowego Add_CF do r10. Jeśli bo poprzedniej linijce został
        ; CF, to w r10 będzie -1, wpp. będzie 0.
        sbb     r10, r10

        ; Zapis wyniku do pamięci.
        mov     [r9], rax

        ; Zarządzanie wskaźnikami.
        add     rdi, 8          ; A0_ptr++
        add     rsi, 8          ; A1_ptr++
        add     r9, 8           ; Ak_ptr++
        loop    .main_loop      ; automatycznie zmniejsza iterator.


        ; Wskaźniki przesunęły się o jeden za daleko,
        ; więc ostatni element jest pod adresem [ptr - 8]

        ; Obliczenie maski znaku dla A0
        mov     rbp, [rdi - 8]
        sar     rbp, 63         ; rbp = maska znaku A0

        ; Sprawdzenie prawdziewgo znaku różnicy D
        mov     rcx, [rsi - 8]
        sar     rcx, 63         ; rcx = maska znaku A1
        shr     r11, 1          ; Wrzucamy do CF ostatnią pożyczkę z pętli.
        sbb     rcx, rbp        ; rcx = sign(A1) - sign(A0) - CF

        ; Włożenie reszty z mnożenia do zwracanych rejestrów rdx:rax
        mov     rax, rbx
        cqo                     ; Wypełnia rdx bitem znaku rax.

        ; Dodanie reszty z A0 do wyższych bitów
        shr     r10, 1          ; CF = ostatnie Add_CF z pętli
        adc     rax, rbp
        adc     rdx, rbp

        ; Końcowa korekta dla D < 0.
        and     rcx, r8         ; rcx = dolna połowa skorygowanego k (lub zero).
        mov     r10, rcx        ; Kopiujemy dolną połowę do r10.
        sar     r10, 63         ; Automatycznie tworzymy górną połowę.

        sub     rax, rcx        ; Odejmujemy skorygowane k
        sbb     rdx, r10

        ; Zdejmowanie ze stosu zgodnie z ABI.
        pop     rbp
        pop     rbx

        ret
