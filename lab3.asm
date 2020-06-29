.model small
.stack  256
.data
 
Rows            equ    2                ;максимальное количество строк
Columns         equ    2                ;максимальное количество столбцов
myMatrixSize    equ    Rows*Columns     ;максимальный размер матрицы
 
m               dw     Rows                    ;текущее количество строк
n               dw     Columns                 ;текущее количество столбцов
Matrix          dw     myMatrixSize dup(0)     ;матрица
 
NewLine         db     0dh, 0ah, '$'   ;"перевод строки"
msInput         db     'Input matrix', '$'
msCurrent       db     'Current matrix', '$' 


str_len         equ    $-msResult
my_str          db     str_len dup (?)  

msResult        db     'Result: ','$'
asPrompt1       db     'element[', '$'      ;строка приглашения
asPrompt2       db     ',', '$'
asPrompt3       db     ']= ', '$'   

not_memory      db     'ERROR: overflow','$'

Min             dw      -32768
 
kbMinLen        equ     6+1             ;буфер ввода с клавиатуры Fn 0ah
kbInput         db      kbMinLen,kbMinLen dup(0)
 
.code 
 
; преобразования строки в число
; на входе:
; ds:[si] - строка с числом
; ds:[di] - адрес числа
; на выходе
; ds:[di] - число
; CF - флаг переноса (при ошибке - установлен, иначе - сброшен)
StringInNumber PROC
        push    ax
        push    bx
        push    cx
        push    dx
        push    ds
        push    es
        push    si
        push    ds
        pop     es
 
        mov     cl, ds:[si]
        xor     ch, ch
 
        inc     si
 
        mov     bx, 10
        xor     ax, ax
 
        ;если в строке первый символ '-'
        ; - перейти к следующему
        ; - уменьшить количество рассматриваемых символов
        cmp     [si], '-'
        jne     Conversion
        inc     si
        dec     cx
Conversion:
        mul     bx         ; умножаем ax на 10 ( dx:ax=ax*bx )
        mov     [di], ax   ; игнорируем старшее слово
        cmp     dx, 0      ; проверяем, результат на переполнение
        jnz     Error
        mov     al, [si]   ; Преобразуем следующий символ в число
        cmp     al, '0'
        jb      Error
        cmp     al, '9'
        ja      Error
        sub     al, '0'
        xor     ah, ah
        add     ax, [di]
        jc      Error    
        cmp     ax, 8000h  ;32768
        ja      Error
        inc     si
 
        loop    Conversion
 
        pop     si         ;проверка на знак
        push    si
        inc     si
        cmp     byte ptr [si], '-'
        jne     Check    ;если должно быть положительным
        neg     ax       ;если должно быть отрицательным
        jmp     SavingResult
Check:                   ;дополнительная проверка, когда при вводе положительного числа получили отрицательное
        or      ax, ax   
        js      Error
SavingResult:            ;сохранить результат
        mov     [di], ax
        clc
        pop     si
        pop     es
        pop     ds
        pop     dx
        pop     cx
        pop     bx
        pop     ax
        ret
Error:
        xor     ax, ax
        mov     [di], ax
        stc
        pop     si
        pop     es
        pop     ds
        pop     dx
        pop     cx
        pop     bx
        pop     ax
        ret
StringInNumber ENDP
 
; выводит число из регистра AX на экран
; входные данные:
; ax - число для отображения
Show_AX proc
        push    ax
        push    bx
        push    cx
        push    dx
        push    di
 
        mov     cx, 10
        xor     di, di          ; di - кол. цифр в числе
 
        ; если число в ax отрицательное, то
        ;1) напечатать '-'
        ;2) сделать ax положительным
        or      ax, ax
        jns     NoNumberSign
        push    ax
        mov     dx, '-'
        mov     ah, 2           ; ah - функция вывода символа на экран
        int     21h
        pop     ax
 
        neg     ax
 
NoNumberSign:
        xor     dx, dx
        div     cx              ; dl = num mod 10
        add     dl, '0'         ; перевод в символьный формат
        inc     di
        push    dx              ; складываем в стэк
        or      ax, ax
        jnz     NoNumberSign
        ; выводим из стэка на экран
Show:
        pop     dx              ; dl = очередной символ
        mov     ah, 2           ; ah - функция вывода символа на экран
        int     21h
        dec     di              ; повторяем пока di<>0
        jnz     Show
 
        pop     di
        pop     dx
        pop     cx
        pop     bx
        pop     ax
        ret
Show_AX endp
 
; На входе
;m     - количество строк
;n     - количество столбцов
;ds:dx - адрес матрицы
ShowMatrix PROC 
        pusha
        mov     si, 0  ; строка
        mov     di, 0  ; столбец
        mov     bx, dx
 
ShowRow:
        mov     ax, [bx]
        call    Show_AX
 
        mov     ah, 02h
        mov     dl, ' '
        int     21h
 
        add     bx, 2
 
        inc     di
 
        cmp     di, n
        jb      ShowRow
 
        mov     dx, OFFSET NewLine
        mov     ah, 09h
        int     21h
 
        mov     di, 0 
        inc     si 
        cmp     si, m
        jb      ShowRow
 
        popa
        ret
ShowMatrix ENDP
 
; На входе
;ds:dx - адрес матрицы
InputMatrix PROC
        pusha
        ;bx - адрес очередного элемента матрицы
        mov     bx, dx
        ;Вывод на экран приглашения ввести матрицу
        mov     ah, 09h
        mov     dx, OFFSET msInput
        int     21h
 
        mov     ah, 09h
        mov     dx, OFFSET NewLine
        int     21h
 
        mov     si, 1  ; строка (индекс)
        mov     di, 1  ; столбец (индекс)
InpInt:   
        mov     ah, 09h
        mov     dx, OFFSET NewLine
        int     21h
        ;вывод на экран приглашения 'a[1,1]='
        lea     dx, asPrompt1
        mov     ah, 09h
        int     21h
        mov     ax,     si
        call    Show_AX
        lea     dx, asPrompt2
        mov     ah, 09h
        int     21h
        mov     ax,     di
        call    Show_AX
        lea     dx, asPrompt3
        mov     ah, 09h
        int     21h
 
        ;Ввод строки
        mov     ah, 0ah
        mov     dx, OFFSET kbInput
        int     21h
 
        ;Преобразование строки в число
        push    di
        push    si
        mov     si, OFFSET kbInput+1
        mov     di, bx
        call    StringInNumber
        pop     si
        pop     di
        jc      InpInt  ; если ошибка преобразования - повторить ввод
        
        cmp     word ptr [bx],  32767
        jle     YetTest
        jmp     InpInt
YetTest:
        cmp     word ptr [bx],  -32768
        jge     AllGood
        jmp     InpInt
AllGood:
        ;на экране - перейти к следующей строке
        mov     dx, OFFSET NewLine
        mov     ah, 09h
        int     21h
        ;перейти к следующему элементу матрицы
        add     bx, 2 
        inc     di 
        cmp     di, n
        jbe     InpInt 
        mov     di, 1 
        inc     si 
        cmp     si, m
        jbe     InpInt 
        popa
        ret
InputMatrix ENDP 




error_message proc
        mov     dx, OFFSET not_memory
        mov     ah, 09h
        int     21h
        mov     ax, 4c00h
        int     21h
    ENDP

 
Main:
        mov     dx, @data
        mov     ds, dx
 
        mov     dx, OFFSET Matrix
        call    InputMatrix
 
        mov     ah, 09h
        mov     dx, OFFSET msCurrent
        int     21h
 
        mov     ah, 09h
        mov     dx, OFFSET NewLine
        int     21h
 
        mov     dx, OFFSET Matrix
        call    ShowMatrix
        
        
        
        
        ;поиск минимальной суммы в столбцах
        mov     ax, 7FFFh   ;максимальное значение суммы в матрице
        mov     dx, n       ;приращение смещения адреса для перехода
        shl     dx, 1       ;к следующему элементу столбца
        mov     cx, n
        lea     si, Matrix   
        

ForJ:                   ;цикл по строкам
        mov     bx, 0   ;сумма элементов столбца
        push    cx
        mov     cx, m   ;количество элементов в столбце
        push    si
        ForI:
                add     bx, [si]
                 jo     error_message        
                add     si, dx  
               
                loop    ForI       
        pop     si
        pop     cx
 
        cmp     ax, bx
        jle     Next
        mov     ax, bx 
        mov     [Min], ax
Next:
        add     si, 2
        loop    ForJ  
        
;Вывод результатов на экран  ==================================================================================== 
            
        pushf        
        pusha     
        xor     cx, cx
        xor     si, si
        xor     di, di
        mov	    cx, str_len
        lea	    si, msResult
        lea	    di, my_str
        rep	movsb    
        ;========================================================================================================
          
        popa
        popf

        mov     ah, 09h
        mov     dx, OFFSET my_str
        int     21h
 
        mov     ah, 09h
        mov     dx, OFFSET NewLine
        int     21h     
            
;поиск индексов с минимальной суммой в столбцах
        
        mov     di, 0       ;номер столбца с максимальной суммой
        mov     dx, n       ;приращение смещения адреса для перехода
        shl     dx, 1       ;к следующему элементу столбца
        mov     cx, n
        lea     si, Matrix   
        

ForJ2:                      ;цикл по строкам
        mov     bx, 0       ;сумма элементов столбца
        push    cx
        mov     cx, m       ;количество элементов в
        push    si
       ForI2:
                add     bx, [si]
                add     si, dx
                loop    ForI2
        pop     si
        pop     cx
 
        cmp     [Min], bx
        jne     Next2
      
        mov     di, n       ;di - номер столбца с максимальной суммой
        sub     di, cx  
        
        mov     ax, di
        inc     ax
                                   
        pushf        
        pusha
        
        add ax, 48
        mov dx, ax
        mov ah,02h
        int 21h
        
        
        mov     ah, 09h
        mov     dx, OFFSET NewLine
        int     21h
        popa
        popf
                             
Next2:
        add     si, 2
        loop    ForJ2        


ExitFromProg:        
        mov     ax, 4c00h
        int     21h
         
END     Main