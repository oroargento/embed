0 ok! ( Turn off 'ok' prompt )
\ @file meta.fth
\ @author Richard James Howe
\ @license MIT
\ @copyright Richard James Howe, 2017
\ @brief A Meta-compiler, an implementation of eForth and a tutorial on both.
\ Project site: <https://github.com/howerj/embed>

only forth definitions hex
\ This file contains a metacompiler (also more commonly know as a cross-
\ compiler) and a program to be cross compiled. The cross compiler targets
\ a stack based virtual machine designed to run Forth. The cross compiled
\ program is a Forth interpreter. The file also contains a tutorial about
\ how to make a cross compiler in Forth, as well as how to make a working
\ Forth interpreter.

\ The workings of a metacompiler may seem complex, and to understand
\ this tutorial a reasonable understanding of Forth is required, but in
\ actuality the cross compiler is quite simple. The cross compiled program
\ itself is more complex. An understanding of Forth vocabularies is required,
\ which are often glossed over in tutorials, Forth vocabularies are how
\ Forth programmers manage which words go into which namespaces and allow
\ words that are no longer needed to be hidden.

\ The virtual machine that is targeted is suited to building a Forth
\ system but not much else, a more practical Forth virtual machine would
\ concentrate on efficiency and functionality (providing a Foreign Function
\ Interface, and file access words, for example). It is meant to be as
\ simple as possible and no simpler. It will be referred to as the 'Embed
\ virtual machine', or as 'the virtual machine'.

\ The metacompiler is based upon one targeting the J1 CPU, available
\ here <https://github.com/samawati/j1eforth>. The J1 CPU is a "Soft Core"
\ CPU written in Verilog, designed to be run on an FPGA. The J1 CPU is
\ well known in the Forth community, I have made my version written in
\ VHDL called the H2, available at <https://github.com/howerj/forth-cpu>.
\ The original cross compiler, written in C, targeting the Embed
\ virtual machine, was taken and modified from the H2 Project.

\ NOTES/TO DO:
\ * Instead of having a bit for whether a word is an inlineable word,
\ inlineable words could instead be part of a special vocabulary.
\ * Add more references, and turn this program into a literate file.
\    - Add references to eForth implementation guide
\    - Add references to my project
\    - Move diagrams describing the CPU architecture from the
\    'readme.md' file to this one.
\    - Document the Forth virtual machine, moving diagrams
\    from the 'readme.md' file to here.
\    - Add meta-compile time checking (eg. balanced 't:' and 't;')
\    - Hide normal word definitions between 't:' and 't;' that are not
\    in the meta, assembler or target dictionaries 

\ Document plan
\ This program and document are a work in progress, it has been written
\ as if the program has been complete, although it is far from it.
\ The outline of the program/document is:
\ * Introduction
\ * Introduction to Forth
\ * Design trade offs, philosophy of Forth
\ * Dictionary layout
\ * Reference virtual machine
\ * The metacompiler, assembler
\ * The eForth program
\ * Conclusion

( ===                    Metacompilation wordset                    === )      
\ This section defines the metacompilation wordset as well as the
\ assembler. The cross compiler requires a few assembly instructions
\ to be defined before it can be completed so the metacompiler and
\ assembler are not completely separate modules

variable meta       ( Metacompilation vocabulary )
meta +order definitions

variable assembler.1   ( Target assembler vocabulary )
variable target.1      ( Target dictionary )
variable tcp           ( Target dictionary pointer )
variable tlast         ( Last defined word in target )
variable tdoVar        ( Location of doVar in target )
variable tdoConst      ( Location of doConst in target )
5000 constant #target  ( Memory location where the target image will be built )
2000 constant #max     ( Max number of cells in generated image )
2    constant =cell    ( Target cell size )
0    constant optimize ( Turn optimizations on [-1] or off [0] )
variable header -1 header ! ( If true Headers in the target will be generated )

-1   constant verbose  ( )
#target #max 0 fill    ( Erase the target memory location )

: ]asm assembler.1 +order ; immediate ( -- )
: a: get-current assembler.1 set-current : ; ( "name" -- wid link )
: a; [compile] ; set-current ; immediate ( wid link -- )

\ : ?exit if rdrop exit then ;
: there tcp @ ; ( -- a : target dictionary pointer value )
: tc! #target + c! ;
: tc@ #target + c@ ;
: [last] tlast @ ;
( @todo allow for configurable endianess )
: t! over ff and over tc! swap 8 rshift swap 1+ tc! ;
: t@ dup tc@ swap 1+ tc@ 8 lshift or ;
: 2/ 1 rshift ; 
\ : .hex base @ >r hex . cr r> base ! ;
: talign there 1 and tcp +! ;
: tc, there tc! 1 tcp +! ;
: t,  there t!  =cell tcp +! ;
: tallot tcp +! ;
: s! ! ;
: dump-hex #target there 16 + dump ;
: display ( -- : display metacompilation and target information )
  verbose 0= if exit then
  hex
  ." META COMPILATION COMPLETE" cr
  dump-hex
  ." META: "       meta        . cr
  ." TARGET: "     target.1    . cr
  ." ASSEMBLER: "  assembler.1 . cr
  ." TARGET DICTIONARY: " cr
  words
  ." HOST: "       here        . cr
  ." TARGET: "     there       . cr ;
: save-hex ( -- : save target binary to file )
   #target #target there + (save) throw ;

: finished ( -- : save target image and display statistics )
   display 
   only forth definitions hex 
   ." SAVING... " save-hex ." DONE! " cr 
   ." STACK> " .s cr ;

: [a] ( "name" -- : find word and compile an assembler word )
  token assembler.1 search-wordlist 0= if abort" [a]? " then
  cfa compile, ; immediate

\  @bug immediate cannot be placed after 'a;' because of the way linking
\ vocabularies into the dictionary works, in fact the word 'a;' should not be
\ necessary but it is a work around for another hack 
a: asm[ assembler.1 -order ( [ immediate ] ) a; ( -- )

\ ALU Operations
a: #t      0000 a;
a: #n      0100 a;
a: #r      0200 a;
a: #[t]    0300 a;
a: #n->[t] 0400 a;
a: #t+n    0500 a;
a: #t*n    0600 a;
a: #t&n    0700 a;
a: #t|n    0800 a;
a: #t^n    0900 a;
a: #~t     0a00 a;
a: #t-1    0b00 a;
a: #t==0   0c00 a;
a: #t==n   0d00 a;
a: #nu<t   0e00 a;
a: #n<t    0f00 a;
a: #n>>t   1000 a;
a: #n<<t   1100 a;
a: #sp@    1200 a;
a: #rp@    1300 a;
a: #sp!    1400 a;
a: #rp!    1500 a;
a: #save   1600 a;
a: #tx     1700 a;
a: #rx     1800 a;
a: #u/mod  1900 a;
a: #/mod   1a00 a;
a: #bye    1b00 a;

\ The Stack Delta Operations occur after the ALU operations have been executed.
\ They affect either the Return or the Variable Stack. An ALU instruction
\ without one of these operations (generally) do not affect the stacks.
a: d+1     0001 or a; ( increment variable stack by one )
a: d-1     0003 or a; ( decrement variable stack by one )
a: d-2     0002 or a; ( decrement variable stack by two )
a: r+1     0004 or a; ( increment variable stack by one )
a: r-1     000c or a; ( decrement variable stack by one )
a: r-2     0008 or a; ( decrement variable stack by two )

\ All of these instructions execute after the ALU and stack delta operations
\ have been performed except r->pc, which occurs before. They form part of
\ an ALU operation.
a: r->pc   0010 or a; ( Set Program Counter to Top of Return Stack )
a: n->t    0020 or a; ( Set Top of Variable Stack to Next on Variable Stack )
a: t->r    0040 or a; ( Set Top of Return Stack to Top on Variable Stack )
a: t->n    0080 or a; ( Set Next on Variable Stack to Top on Variable Stack )

\ There are five types of instructions; ALU operations, branches, 
\ conditional branches, function calls and literals. ALU instructions
\ comprise of an ALU operation, stack effects and register move bits. Function
\ returns are part of the ALU operation instruction set.
a: alu        6000 or t, a; ( u -- : Compile an ALU operation )
a: branch  2/ 0000 or t, a; ( a -- : Compile an Unconditional branch )
a: ?branch 2/ 2000 or t, a; ( a -- : Compile a  Conditional branch )
a: call    2/ 4000 or t, a; ( a -- : Compile a  Function call )
a: literal ( n -- : compile a number into target )
  dup 8000 and if   ( numbers above $7fff take up two instructions )
    invert recurse  ( the number is inverted, an literal is called again )
    [a] #~t [a] alu ( then an invert instruction is compiled into the target )
  else
    8000 or t, ( numbers below $8000 can be stored in a single instruction )
  then a;
a: return ( -- : Compile a return into the target )
   [a] #t [a] r->pc [a] r-1 [a] alu a;

\ @todo Improve with fence variable set by control structures
\ @todo Use optimizer from "eforth.fth"
: lookback there =cell - t@ ;
: call? lookback e000 and 4000 = ;
: call>goto there =cell - dup t@ 1fff and swap t! ;
: safe? lookback e000 and 6000 = lookback 004c and 0= and ;
: alu>return there =cell - dup t@ [a] r->pc [a] r-1 swap t! ;
: exit,
  call? if
   call>goto else safe? if
    alu>return else
	 [a] return
   then
  then ;

\ create a word in the metacompilers dictionary, not the targets 
: tcreate get-current >r target.1 set-current create r> set-current ;

: thead ( b u -- : compile word header into target dictionary )
  header @ 0= if 2drop exit then
  talign
  there #target + pack$ count nip 1+ aligned tcp +! talign
  [last] t, there tlast !  ;

: lookahead ( -- b u : parse a word, but leave it in the input stream )
  >in @ >r bl parse r> >in ! ;


: t: 
  $f00d
  lookahead
  thead tcreate
  there , does> @ [a] call ;

: h: ( -- : create a word with no name in the target dictionary )
  $f00d
  tcreate there , does> @ [a] call ;

: t; 
   $f00d <> if abort" unstructured! " then
   optimize if exit, else [a] return then ; 

\ @todo Increase efficiency of these variable and constant, when metacompiling
\ constants, the constant itself should be compiled as a literal if and only
\ if the number can be stored in a single cell (is less than $7fff)

: tconstant ( "name", n -- , Run Time: -- n )
  >r
  lookahead
  thead 
  there tdoConst @ [a] call r> t, >r
  tcreate r> ,
  does> @ [a] call ; 

: tvariable ( "name", n -- , Run Time: -- a )
  >r 
  lookahead
  thead 
  there tdoVar @ [a] call r> t, >r
  tcreate r> ,
  does> @ [a] call ; 

: tlocation ( "name", n -- : Reserve space in target for a memory location )
  header @ >r 0 header ! tvariable r> header !  ;

: [t] 
  token target.1 search-wordlist 0= if abort" [t]? " then 
  cfa >body @ ; 
: [u] [t] =cell + ;

: literal [a] literal ;
: begin  there ;
: until  [a] ?branch ;
: if     there 0 [a] ?branch ;
: skip   there 0 [a] branch ;
: then   begin 2/ over t@ or swap t! ;
: else   skip swap then ;
: while  if swap ;
: repeat [a] branch then ;
: again  [a] branch ;
: aft    drop skip begin swap ;
: constant tcreate , does> @ literal ;
: [char] char literal ;

\ Instructions

: nop     ]asm  #t       alu asm[ ;
: dup     ]asm  #t       t->n   d+1   alu asm[ ;
: over    ]asm  #n       t->n   d+1   alu asm[ ;
: invert  ]asm  #~t      alu asm[ ;
: um+     ]asm  #t+n     alu asm[ ;
: +       ]asm  #t+n     n->t   d-1   alu asm[ ;
: um*     ]asm  #t*n     alu asm[    ;
: *       ]asm  #t*n     n->t   d-1   alu asm[ ;
: swap    ]asm  #n       t->n   alu asm[ ;
: nip     ]asm  #t       d-1    alu asm[ ;
: drop    ]asm  #n       d-1    alu asm[ ;
: exit    ]asm  #t       r->pc  r-1   alu asm[ ;
: >r      ]asm  #n       t->r   d-1   r+1   alu asm[ ;
: r>      ]asm  #r       t->n   d+1   r-1   alu asm[ ;
: r@      ]asm  #r       t->n   d+1   alu asm[ ;
: @       ]asm  #[t]     alu asm[ ;
: !       ]asm  #n->[t]  d-1    alu asm[ ;
: rshift  ]asm  #n>>t    d-1    alu asm[ ;
: lshift  ]asm  #n<<t    d-1    alu asm[ ;
: =       ]asm  #t==n    d-1    alu asm[ ;
: u<      ]asm  #nu<t    d-1    alu asm[ ;
: <       ]asm  #n<t     d-1    alu asm[ ;
: and     ]asm  #t&n     d-1    alu asm[ ;
: xor     ]asm  #t^n     d-1    alu asm[ ;
: or      ]asm  #t|n     d-1    alu asm[ ;
: sp@     ]asm  #sp@     t->n   d+1   alu asm[ ;
: sp!     ]asm  #sp!     alu asm[ ;
: 1-      ]asm  #t-1     alu asm[ ;
: rp@     ]asm  #rp@     t->n   d+1   alu asm[ ;
: rp!     ]asm  #rp!     d-1    alu asm[ ;
: 0=      ]asm  #t==0    alu asm[ ;
: nop     ]asm  #t       alu asm[ ;
: (bye)   ]asm  #bye     alu asm[ ;
: rx?     ]asm  #rx      t->n   d+1   alu asm[ ;
: tx!     ]asm  #tx      n->t   d-1   alu asm[ ;
: (save)  ]asm  #save    d-1    alu asm[ ;
: u/mod   ]asm  #u/mod   t->n   alu asm[ ;
: /mod    ]asm  #u/mod   t->n   alu asm[ ;
: /       ]asm  #u/mod   d-1    alu asm[ ;
: mod     ]asm  #u/mod   n->t   d-1   alu asm[ ;
: rdrop   ]asm  #t       r-1    alu asm[ ;

: for >r begin ;
\ @todo make a more compact 'next' construct
: next r@ while r> 1- >r repeat r> drop ; 

\ : inline target.1 @ @ 8000 or target.1 @ ! ;
\ : immediate target.1 @ @ 4000 or target.1 @ ! ;

$20   constant =bl         ( blank, or space )
$d    constant =cr         ( carriage return )
$a    constant =lf         ( line feed )
$8    constant =bs         ( back space )
$1b   constant =escape     ( escape character )
$ffff constant eof         ( end of file )

$10   constant dump-width  ( number of columns for 'dump' )
$50   constant tib-length  ( size of terminal input buffer )
$50   constant pad-length  ( pad area begins HERE + pad-length )
$1f   constant word-length ( maximum length of a word )

$40   constant c/l ( characters per line in a block )
$10   constant l/b ( lines in a block )
$4400 constant sp0 ( start of variable stack )
$7fff constant rp0 ( start of return stack )

( Volatile variables )
$4000 constant _test       ( used in skip/test )
$4002 constant last-def    ( last, possibly unlinked, word definition )
$4004 constant csp         ( stack pointer for error checking )
$4006 constant id          ( used for source id )
$4008 constant seed        ( seed used for the PRNG )
$400A constant handler     ( current handler for throw/catch )
$400C constant block-dirty ( -1 if loaded block buffer is modified )
$4010 constant _key        ( -- c : new character, blocking input )
$4012 constant _emit       ( c -- : emit character )
$4014 constant _expect     ( "accept" vector )
\ $4016 constant _tap      ( "tap" vector, for terminal handling )
\ $4018 constant _echo     ( c -- : emit character )
$4020 constant _prompt     ( -- : display prompt )
$4110 constant context     ( holds current context for search order )
$4122 constant #tib        ( Current count of terminal input buffer )
$4124 constant tib-buf     ( ... and address )
$4126 constant tib-start   ( backup tib-buf value )

( ===                        Target Words                           === )
\ With the assembler and meta compiler complete, we can now make our target
\ application, a Forth interpreter which will be able to read in this file
\ and create new, possibly modified, images for the Forth virtual machine
\ to run.

target.1 +order

\ t: r1- r> r> 1- >r >r t;

\ @todo add data to the beginning of the image that would allow the binary 
\ format to be identified by an external program, this should include:
\ - A Magic number format identifier
\ - Endianess of format
\ - Version number
\ - Length and CRC checks
\ The first two 16-bit cells contain the start vector and the trap
\ handler

meta -order meta +order 
4 tallot 
h: doVar   r> t;
h: doConst r> @ t;

[t] doVar tdoVar s!
[t] doConst tdoConst s!

0 tlocation cp                ( Dictionary Pointer: Set at end of file )
0 tlocation root-voc          ( root vocabulary )
0 tlocation editor-voc        ( editor vocabulary )
0 tlocation assembler-voc     ( assembler vocabulary )
0 tlocation _forth-wordlist   ( set at the end near the end of the file )
0 tlocation _words            ( words execution vector )
0 tlocation _forth            ( forth execution vector )
0 tlocation _set-order        ( set-order execution vector )
0 tlocation _do_colon         ( execution vector for ':' )
0 tlocation _do_semi_colon    ( execution vector for ';' )
0 tlocation _boot             ( -- : execute program at startup )
0 tlocation current           ( WID to add definitions to )
\ 0 tlocation _message        ( n -- : display an error message )
 
h: execute-location @ >r t; 
t: forth-wordlist _forth-wordlist t;
t: words _words execute-location t;
t: set-order _set-order execute-location t;
t: forth _forth execute-location t;
\ @todo Check if this is correct
[u] root-voc [last] t! 0 tlast s!  

\ === ASSEMBLY INSTRUCTIONS ===
\ @note If assembly instructions are to be inlined, 't;' will need to be 
\ replaced with 'nop t;', to trick the optimizer
\ @todo Inline these words when they appear between 't:' and 't;', instead of 
\ calling them, for efficiency reasons.
t: nop      nop      t;
t: dup      dup      t;
t: over     over     t;
t: invert   invert   t;
t: um+      um+      t;
t: +        +        t;
t: um*      um*      t;
t: *        *        t;
t: swap     swap     t;
t: nip      nip      t;
t: drop     drop     t;
\ t: exit     exit     t;
t: >r       >r       t; ( compile-only )
t: r>       r>       t; ( compile-only )
t: r@       r@       t; ( compile-only )
t: @        @        t;
t: !        !        t;
t: rshift   rshift   t;
t: lshift   lshift   t;
t: =        =        t;
t: u<       u<       t;
t: <        <        t;
t: and      and      t;
t: xor      xor      t;
t: or       or       t;
t: sp@      sp@      t;
t: sp!      sp!      t;
t: 1-       1-       t;
t: rp@      rp@      t;
t: rp!      rp!      t;
t: 0=       0=       t;
t: nop      nop      t;
t: (bye)    (bye)    t;
t: rx?      rx?      t;
t: tx!      tx!      t;
t: (save)   (save)   t;
t: u/mod    u/mod    t;
t: /mod     /mod     t;
t: /        /        t;
t: mod      mod      t;
t: rdrop    rdrop    t;

\ @todo make immediate
t: end-code forth _do_semi_colon execute-location t; ( immediate )
[u] assembler-voc [last] t! 

t: assembler root-voc assembler-voc 2 literal set-order t;
t: ;code assembler t; ( immediate )
t: code _do_colon execute-location assembler t;

$2    tconstant cell  ( size of a cell in bytes )
$0    tvariable >in   ( Hold character pointer when parsing input )
$0    tvariable state ( compiler state variable )
$0    tvariable hld   ( Pointer into hold area for numeric output )
$10   tvariable base  ( Current output radix )
$0    tvariable span  ( Hold character count received by expect   )
$8    tconstant #vocs ( number of vocabularies in allowed )
$400  tconstant b/buf ( size of a block )
0     tvariable blk   ( current blk loaded, set in 'cold' )
$1984 tconstant ver   ( eForth version )

\ location .s-string     " <sp"        ( used by .s )
\ location see.unknown   "???"         ( used by 'see' for unknown words )
\ location see.lit       "LIT"         ( decompilation -> literal )
\ location see.alu       "ALU"         ( decompilation -> ALU operation )
\ location see.call      "CAL"         ( decompilation -> Call )
\ location see.branch    "BRN"         ( decompilation -> Branch )
\ location see.0branch   "BRZ"         ( decompilation -> 0 Branch )
\ location see.immediate " immediate " ( used by "see", for immediate words )
\ location see.inline    " inline "    ( used by "see", for inline words )
\ location OK            " ok"         ( used by "prompt" )
\ location redefined     " redefined"  ( used by ":" when a word is redefined )
\ location hi-string     "eFORTH V"    ( used by "hi" )

\ === ASSEMBLY INSTRUCTIONS ===
t: 2drop drop drop t;       ( n n -- )
t: 1+ 1 literal + t;        ( n -- n : increment a value  )
t: negate invert 1+ t;      ( n -- n : negate a number )
t: - negate + t;            ( n1 n2 -- n : subtract n1 from n2 )
t: aligned dup 1 literal and + t;   ( b -- a )
t: bye 0 literal (bye) t;    ( -- : leave the interpreter )
t: cell- cell - t;           ( a -- a : adjust address to previous cell )
t: cell+ cell + t;           ( a -- a : move address forward to next cell )
t: cells 1 literal lshift t; ( n -- n : convert cells count to address count )
t: chars 1 literal rshift t; ( n -- n : convert bytes to number of cells )
t: ?dup dup if dup exit then t; ( n -- 0 | n n : duplicate non zero value )
t: >  swap < t;              ( n1 n2 -- f : signed greater than, n1 > n2 )
t: u> swap u< t;             ( u1 u2 -- f : unsigned greater than, u1 > u2 )
t: u>= u< invert t;          ( u1 u2 -- f : )
t: <> = invert t;            ( n n -- f : not equal )
t: 0<> 0= invert t;          ( n n -- f : not equal  to zero )
t: 0> 0 literal > t;         ( n -- f : greater than zero? )
t: 0< 0 literal < t;         ( n -- f : less than zero? )
t: 2dup over over t;         ( n1 n2 -- n1 n2 n1 n2 )
t: tuck swap over t;         ( n1 n2 -- n2 n1 n2 )
t: +! tuck @ + swap ! t;     ( n a -- : increment value at address by 'n' )
t: 1+!  1 literal swap +! t; ( a -- : increment value at address by 1 )
t: 1-! -1 literal swap +! t; ( a -- : decrement value at address by 1 )
t: execute >r t;             ( cfa -- : execute a function )
t: c@ dup  @ swap 1 literal and 
   if 
      8 literal rshift exit 
   else $ff literal and exit 
   then t; ( b -- c ) 
t: c!                       ( c b -- )
  swap $ff literal and dup 8 literal lshift or swap
  swap over dup ( -2 and ) @ swap 1 literal and 0 literal = $ff literal xor
  >r over xor r> and xor swap ( -2 and ) ! t;
t: 2! ( d a -- ) tuck ! cell+ ! t;     ( n n a -- )
t: 2@ ( a -- d ) dup cell+ @ swap @ t; ( a -- n n )
t: command? state @ 0= t;     ( -- f )
t: get-current current @ t;
t: set-current current ! t;
t: here cp @ t;               ( -- a )
t: align here aligned cp ! t; ( -- )

t: source #tib 2@ t;                    ( -- a u )
t: source-id id @ t;                    ( -- 0 | -1 )
t: pad here pad-length + t;             ( -- a )
h: @execute @ ?dup if >r then t;        ( cfa -- )
t: bl =bl t;                            ( -- c )
t: within over - >r - r> u< t;          ( u lo hi -- f )
\ t: dnegate invert >r invert 1 literal um+ r> + t; ( d -- d )
t: abs dup 0< if negate exit then t;    ( n -- u )
t: count dup 1+ swap c@ t;              ( cs -- b u )
t: rot >r swap r> swap t;               ( n1 n2 n3 -- n2 n3 n1 )
t: -rot swap >r swap r> t;              ( n1 n2 n3 -- n3 n1 n2 )
\ h: 2>r r> -rot >r >r >r t;            ( u1 u2 --, R: -- u1 u2 )
\ h: 2r> r> r> r> rot >r t;             ( -- u1 u2, R: u1 u2 -- )
h: doNext r> r> ?dup if 1- >r @ >r exit then cell+ >r t; 
t: min 2dup < if drop exit else nip exit then t; ( n n -- n )
t: max 2dup > if drop exit else nip exit then t; ( n n -- n )
h: >char $7f literal and dup $7f literal =bl within 
         if drop [char] _ then t;       ( c -- c ) 
h: tib #tib cell+ @ t;                  ( -- a )
\ h: echo _echo @execute t;             ( c -- )
t: key _key @execute dup eof = if bye then t; ( -- c )
t: allot cp +! t;                       ( n -- )
h: over+ over + t;                      ( u1 u2 -- u1 u1+2 )
t: /string over min rot over+ -rot - t; ( b u1 u2 -- b u : advance string u2 )
h: +string 1 literal /string t;         ( b u -- b u : )
h: address $3fff literal and t;         ( a -- a : mask off address bits )
h: @address @ address t;                ( a -- a )
h: last get-current @address t;         ( -- pwd )
t: emit _emit @execute t;               ( c -- : write out a char )
h: toggle over @ xor swap ! t;          ( a u -- : xor value at addr with u )
t: cr =cr emit =lf emit t;              ( -- )
t: space =bl emit t;                    ( -- )
h: depth sp@ sp0 - chars t;             ( -- u )
h: vrelative cells sp@ swap - t;        ( -- u )
t: pick  vrelative @ t;                 ( vn...v0 u -- vn...v0 vu )
h: typist ( b u f -- : print a string )
  >r begin dup while 
    swap count r@ 
    if 
      >char 
    then 
    emit 
    swap 1- 
  repeat 
  rdrop 2drop t;  
t: type 0 literal typist t;                           ( b u -- )
h: $type -1 literal typist t; 
h: print count type t;                ( b -- )
h: decimal? $30 literal $3a literal within t; ( c -- f : decimal char? )
h: lowercase? [char] a [char] { within t;   ( c -- f )
h: uppercase? [char] A [char] [ within t;   ( c -- f )
h: >lower ( c -- c : convert to lower case )
  dup uppercase? if =bl xor exit then t;  
h: nchars ( +n c -- : emit c n times ) 
  swap 0 literal max for aft dup emit then next drop t;  
t: spaces =bl nchars t;                     ( +n -- )
t: cmove for aft >r dup c@ r@ c! 1+ r> 1+ then next 2drop t; ( b b u -- )
t: fill swap for swap aft 2dup c! 1+ then next 2drop t; ( b u c -- )

t: catch
  sp@ >r
  handler @ >r
  rp@ handler !
  execute
  r> handler !
  r> drop 0 literal t;

t: throw
  ?dup if
    handler @ rp!
    r> handler !
    r> swap >r
    sp! drop r>
  then t;

h: -throw negate throw t;  ( space saving measure )
[t] -throw 2/ 2 t! ( @todo test this )

h: ?ndepth depth 1- u> if 4 literal -throw exit then t; 
h: 1depth 1 literal ?ndepth t; 

\ constant #bits $f 
\ constant #high $e ( number of bits - 1, highest bit )
\ t: um/mod ( ud u -- ur uq )
\   ?dup 0= if $a literal -throw exit then
\   2dup u<
\   if negate #high
\     for >r dup um+ >r >r dup um+ r> + dup
\       r> r@ swap >r um+ r> or
\       if >r drop 1+ r> else drop then r>
\     next
\     drop swap exit
\   then drop 2drop -1 literal dup t;

\ t: m/mod ( d n -- r q ) \ floored division
\   dup 0< dup >r
\   if
\     negate >r dnegate r>
\   then
\   >r dup 0< if r@ + then r> um/mod r>
\   if swap negate swap exit then t;

t: decimal $a literal base ! t;                       ( -- )
t: hex     $10 literal base ! t;                       ( -- )
h: radix base @ dup 2 literal - $22 literal u> 
  if hex $28 literal -throw exit then t; 
h: digit  9 literal over < 7 literal and + $30 literal + t; ( u -- c )
h: extract u/mod swap t;               ( n base -- n c )
h: ?hold hld @ here u< if $11 literal -throw exit then t;  ( -- )
t: hold  hld @ 1- dup hld ! ?hold c! t;      ( c -- )
\ t: holds begin dup while 1- 2dup + c@ hold repeat 2drop t;
t: sign  0< if [char] - hold exit then t;    ( n -- )
t: #>  drop hld @ pad over - t;               ( w -- b u )
t: #  1depth radix extract digit hold t;     ( u -- u )
t: #s begin # dup while repeat t;            ( u -- 0 )
t: <#  pad hld ! t;                          ( -- )
h: str ( n -- b u : convert a signed integer to a numeric string ) 
  dup >r abs <# #s r> sign #> t;  
h: adjust over - spaces type t;   ( b n n -- )
t:  .r >r str r> adjust t;  ( n n : print n, right justified by +n )
h: (u.) <# #s #> t;   ( u -- : )
t: u.r >r (u.) r> adjust t; ( u +n -- : print u right justified by +n)
t: u.  (u.) space type t;   ( u -- : print unsigned number )
t:  . ( n -- print space, signed number )  
   radix $a literal xor if u. exit then str space type t; 
t: ? @ . t; ( a -- : display the contents in a memory cell )
\ t: .base base @ dup decimal base ! t; ( -- )

\ 6a tconstant test-constant
6a constant test-constant
6a tvariable test-variable
6b [u] test-variable t!

t: test-word
    [t] tx! literal _emit !

    999 literal . cr
    test-constant tx! 
    test-variable @ tx!
    6b literal emit
    6b literal tx! cr bye t;
  \ begin rx? tx! again t;
  \ begin test-constant tx! again t;

\ @todo Many variables need setting before things will work, like
\ _emit, cp, etcetera. 
[t] test-word 2/ 0 t! ( set starting word )
  
\ .set cp  $pc
there [u] cp t!

\ .set _do_colon      ":"
\ .set _do_semi_colon ";"
\ .set _forth         [forth]
\ .set _set-order     [set-order]
\ .set _words         [words]
\ .set _boot          normal-running
\ \ .set _message message  ( execution vector of _message, used in ?error )


( ===                        Target Words                           === )

finished 

