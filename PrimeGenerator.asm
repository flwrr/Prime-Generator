TITLE Prime Generator

; Author:					Christian Ritchie
; Last Modified:			11-19-23
; Description:				Generates and displays a user-specified number of prime numbers.

INCLUDE Irvine32.inc

UPPER_BOUND		= 4000
LOWER_BOUND		= 1
PRIMES_PER_ROW	= 10
ROWS_PER_PAGE	= 20

.data
	; messages
	msg_intro			BYTE	"PRIME GENERATOR", 10, 13, 10, 13, 0
	msg_extraCredit		BYTE	"Output is aligned in columns", 10, 13,
								"Up to 4000 primes can be displayed", 10, 13, 10, 13, 0
	msg_instructions	BYTE	"This program uses the Sieve of Eratosthenes to print prime numbers.", 10, 13,
								"Enter the number of prime numbers you would like to see.", 10, 13, 10, 13, 0
	msg_prompt			BYTE	"Please enter your number (1 <= n <= 4000):  ", 0
	msg_invalidNumber	BYTE	"Invalid input. Try again.", 10, 13, 10, 13, 0
	msg_pressKey		BYTE	"Press any key to view next page...", 10, 13, 0
	msg_farewell		BYTE	"Thank you for participating in this prime-counting enrichment activity.", 10, 13, 0
	msg_printSieve		BYTE	"Press the 'x' key to view the sieve generated.", 10, 13,
								"Press the 'any' key to end.", 10, 13, 0
	msg_spacing			BYTE	"  ", 0
	; user input
	numberOfPrimes		DWORD	0
	; calculation variables
	current_number		DWORD	2	; index for number_list & used as value printed
	sieve_length		DWORD	?
	primes_in_row		DWORD	?	; Current primes in row
	rows_on_page		DWORD	?	; Current rows on page
	; Initialize List of boolean values representing numbers 0 - (UPPER_BOUND * 10)
	number_list			BYTE	(UPPER_BOUND+1)*10 DUP(1)

.code
main PROC
	call	Introduce
	call	GetNumber
	call	ShowPrimes
	call	PrintSieve
	call	Farewell

	Invoke ExitProcess,0	; exit to operating system
main ENDP

; ---------------------------------------------------------------------------------
; Name: Introduce
; 
; Prints the program and programmer's name, extra credit, and instructions.
;
; Preconditions: None.
;
; Postconditions: None.
;
; Receives: None.
;
; Returns: None.
;  ---------------------------------------------------------------------------------
Introduce PROC
	mov		EDX, OFFSET msg_intro
	call	WriteString
	mov		EDX, OFFSET msg_extraCredit
	call	WriteString
	mov		EDX, OFFSET msg_instructions
	call	WriteString
	RET
Introduce ENDP

; ---------------------------------------------------------------------------------
; Name: getNumber
; 
; Prompts the user for a number between 1 and 4000 and test the number entered.
; Calls checkNumber to test whether it lies within the specified bounds.
; If not within bounds, re-prompts the user until a valid number is entered.
;
; Preconditions: None.
;
; Postconditions: `numberOfPrimes` is updated with the validated user input.
;
; Receives: None.
;
; Returns: None.
; ---------------------------------------------------------------------------------
GetNumber PROC
_InputNumber:
	; prompt user to enter the number of primes to be displayed (1 <= n <= 4000)
	mov		EDX, OFFSET msg_prompt
	call	WriteString
    call    ReadInt					; input stored in EAX - ReadInt postcondition
	call	checkNumber				; checkNumber return; EDX = 1: Valid, EDX = 0: Invalid
	cmp		EDX, 1					
	JE		_ValidNumber
_InvalidNumber:						; the user is re-prompted until they enter a valid value 
	mov		EDX, OFFSET msg_invalidNumber
	call	WriteString
	jmp		_InputNumber
_ValidNumber:						; value is stored and procedure ends
	mov		numberOfPrimes, EAX
	call	Crlf
	ret		
GetNumber ENDP

; ---------------------------------------------------------------------------------
; Name: CheckNumber
; Subprocedure to GetNumber; checks whether the num entered in GetNumber is in bounds.
; 
; Preconditions: EAX - Number to be checked.
;
; Postconditions: None.
;
; Receives: EAX - Number to be tested.
;
; Returns: EDX - Result; 1 = within range, 0 = out of range
; ---------------------------------------------------------------------------------
CheckNumber PROC
	cmp		EAX, LOWER_BOUND
	JL		_Invalid
	cmp		EAX, UPPER_BOUND
	JG		_Invalid
_Valid:
	mov		EDX, 1
	ret
_Invalid:
	mov		EDX, 0
	ret
CheckNumber	ENDP

; ---------------------------------------------------------------------------------
; Name: ShowPrimes
;
; Displays prime numbers up to the user-specified number.
; **EC: Formats primes output aligned in columns and pages with 20 rows per page.
;
; Preconditions: `numberOfPrimes` contains the number of primes to display.
;
; Postconditions: Modifies EAX, ECX, EDX, ESI, EBX registers.
;
; Receives: None.
;
; Returns: None.
; ---------------------------------------------------------------------------------
ShowPrimes PROC
	; Find and store the length of the sieve. Ranges from 10 - 40,000
	; (Assumes first n primes can found within 0 - n)
	mov		EAX, numberOfPrimes
	mov		EDX, 10
	MUL		EDX
	mov		sieve_length, EAX
	; Set first two values in number_list (representing numbers 0 and 1) to 0 (False)
	; This is because 0 and 1 are not primes.
	mov		[number_list + 0], 0
	mov		[number_list + 1], 0
	; Initialize registers and global variables
	mov		ECX, numberOfPrimes		; Set the outer loop count to the number of primes requested.
	mov		ESI, OFFSET number_list
	mov		primes_in_row, 0		; Initialize count of curnet primes per row
	mov		rows_on_page,  0		; Initialize count of currnet rows on page

_PrintPrime:
	call	IsPrime					; Postcondition: EAX - Prime to print
	call	WriteDec				; Print prime stored in EAX
	inc		primes_in_row
	cmp		primes_in_row, PRIMES_PER_ROW
	JB		_FindSpacing			; Jump to determine spacing if row is unfinished
	; Start new line and skip the printing of spacing
	call	Crlf
	mov		primes_in_row, 0		; Reset number of current primes in row
	inc		rows_on_page
	cmp		rows_on_page, ROWS_PER_PAGE
	JAE		_NewPage
	JMP		_EndCurrentPrint

	; Find the number of digits of the prime to determine the spacing that should follow.
_FindSpacing:
	push	EAX			; Preserve registers	
	push	ECX			

	mov		ECX, 6		; Initialize ECX as number of spaces to be printed
_Divide:				; Each division by 10 resulting in a dividend above 0 subtracts a space from ECX
	dec		ECX		
	mov		EBX, 10
	CDQ                 ; sign-extends eax into edx:eax
	DIV		EBX			; DIV 32bit preconditions:  EDX:EAX - dividend. reg32/mem32 - divisor
	cmp		EAX, 0		; DIV 32bit postconditions: EAX - quotient. EDX - remainder
	JA		_Divide		
_PrintSpaces:
	mov		AL, 32		; 32 is Ascii for space, " "
	call	WriteChar
	LOOP	_PrintSpaces
	; Print general spacing following spacing to make up for digit differences
	mov		EDX, OFFSET msg_spacing
	call	WriteString

	pop		ECX			; Restore registers
	pop		EAX			
	JMP		_EndCurrentPrint

_EndCurrentPrint:
	LOOP	_PrintPrime
	ret

_NewPage:
	cmp		ECX, 1
	JE		_EndCurrentPrint	; Skips message if page is the final page
	call	Crlf
	mov		EDX, OFFSET msg_pressKey
	mov		rows_on_page, 0
	call	WriteString
	call	ReadChar
	call	Crlf
	JMP		_EndCurrentPrint

ShowPrimes	ENDP

; ---------------------------------------------------------------------------------
; Name: isPrime
; Subprocedure of numberOfPrimes.
; Determines the next prime number and updates the sieve to mark multiples of this prime.
;
; Preconditions: `current_number` contains the current number to check if prime.
;
; Postconditions: `current_number` is updated to the next prime number.
;
; Receives: None.
;
; Returns: EAX - next prime number.
; ---------------------------------------------------------------------------------
IsPrime PROC
_FindPrime:
	mov		EAX, current_number
	add		EAX, OFFSET number_list
	movzx	EAX, byte ptr [EAX]
	cmp		EAX, 1
	JE		_PrimeFound
	inc		current_number
	JMP		_FindPrime

	; Loop to find multiples of the prime and mark them as not prime (False; 0) on the list
	_PrimeFound:
	mov		EAX, current_number		; Initialize EAX as the first multiple of the current number
	_UpdateSieve:
	add		EAX, current_number		; Increment EAX by the current number to find its next multiple
	JO		_ReturnToPrint			; Test whether the result of addition resulted in an overflow
	cmp		EAX, sieve_length
	JA		_ReturnToPrint			; Test whether the new multiple is beyond the sieve length
	mov		number_list[EAX], 0
	JMP		_UpdateSieve

_ReturnToPrint:
;	call	PrintSieve
	mov		EAX, current_number
	inc		current_number
	ret
IsPrime ENDP

; ---------------------------------------------------------------------------------
; Name: Farewell
; 
; Bids the user farewell.
;
; Preconditions: None
;
; Postconditions: None
;
; Recieves: None
;
; Returns: None
; ---------------------------------------------------------------------------------
Farewell PROC
	call	Crlf
	call	Crlf
	mov		EDX, OFFSET msg_farewell
	call	WriteString
	ret
Farewell ENDP

; ---------------------------------------------------------------------------------
; Name: PrintSieve
;
; Prompts the user to press 'x' if they would like to see the sieve generated.
; Prints the contents of `number_list` up to the index equal to `sieve_length`.
;
; Preconditions: `sieve_length` contains the length of the sieve.
;
; Postconditions: ESI and ECX registers are modified.
;
; Receives: None
;
; Returns: None
; ---------------------------------------------------------------------------------
PrintSieve PROC
	; Prompt the user if they would like to see the boolean sieve generated
	call	Crlf
	call	Crlf
	mov		EDX, OFFSET msg_printSieve
	call	WriteString
	call	ReadChar
	cmp		AL, "x"
	JNE		_SkipSievePrint
	call	Crlf

	; Beginning of sieve print
    push	ECX			; Preserve registers
    push	ESI
	push	EDI

    mov		ECX, sieve_length
    mov		ESI, OFFSET number_list
    mov     EDI, 0     ; Initialize elements per row count

    _PrintLoop:
        ; Print the current sieve element
        movzx	EAX, byte ptr [ESI]	; Zero extend byte at ESI and move to EAX to print
        call	WriteDec
        inc		ESI			; Increment to the next element and update row element counter
        inc     EDI
        cmp     EDI, 100	; Check if 100 elements have been printed
        jne     _ContinuePrinting
        ; Start a new line after 100 elements
        call    Crlf
        mov     EDI, 0
    _ContinuePrinting:
        loop	_PrintLoop
    call	Crlf			

	pop		EDI			; Restore registers
    pop		ESI
    pop		ECX
_SkipSievePrint:
    ret
PrintSieve ENDP

END main
