%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include "listaSimbolos.h"
#include "listaCodigo.h"


extern int yylex();
extern int yylineno;

/* Variables auxiliares para el conteo de  errores */
extern int err_lexicos;
int err_sintacticos = 0;
int err_semanticos = 0;
int err_gen_cod = 0;

/* Variables para la generación de etiquetas y strings */
int num_string = 1;
int contador_etiq = 1;

/* Predeclaración de las funciones auxiliares */
void yyerror(const char *msg);
int ok();
void imprimirLS();
void imprimirLC(ListaC listaC);
char* obtenerReg();
void liberarReg(char* reg);
char* concatena(char* arg1, char* arg2);
char* concatenaInt (char* arg1, int valor);
char* nuevaEtiqueta();

/* Lista de símbolos */
Lista lista;
/* Array para los registros temporales */
char temp[10] = {0};
%}

/* Dependencias de los tipos de %union */
%code requires {
    #include "listaCodigo.h"
}

/* Tokens de la gramática */

%token MAIN         "main"
%token <str>IDENT   "id"
%token <str> ENTERO "num"
%token SEMICOLON    ";"
%token COLON        ":"
%token DOT          "."
%token COMMA        ","
%token PLUSOP       "+"
%token MINUSOP      "-"
%token STAR         "*"
%token SLASH        "/"
%token LPAREN       "("
%token RPAREN       ")"
%token ASSIGNOP     ":="
%token <str>STRING  "string"
%token PROGRAM      "program"
%token FUNCTION     "function"
%token CONST        "const"
%token VAR          "var"
%token INTEGER      "integer"
%token BEGINN       "begin"
%token END          "end"
%token IF           "if"
%token THEN         "then"
%token ELSE         "else"
%token WHILE        "while"
%token DO           "do"
%token FOR          "for"
%token TO           "to"
%token WRITE        "write"
%token READ         "read"

/* Flags de funcionamiento de Bison*/
%define parse.error verbose /* para que los errores sean indicados con los símbolos, en vez de con el nombre de token */

/* Precedencia y asociatividad de operadores */
%left "+" "-"
%left "*" "/"
%nonassoc UMENOS

/*
    Indicamos que sólo debe darse un conflicto desplaza/reduce.
    Este ocurrirá en if-else
*/
%expect 1

%type <codigo> expression statement print_item print_list read_list compound_statement
               optional_statements statements declarations constants

%union {
    char *str;
    ListaC codigo;
}

%%

/* Reglas de producción */

program             : { lista = creaLS(); } "program" "id" "(" ")" ";" functions declarations compound_statement "."
                      {
                            if (ok())
                            {
                                /*
                                    Obtenemos la lista de código final, que contiene todas las instrucciones
                                    que componen nuestro programa en ensamblador
                                */
                                concatenaLC($8, $9);
                                liberaLC($9);

                                //Generamos el código ensamblador
                                imprimirLS();
                                imprimirLC($8);

                                //Liberamos la memoria dinámica
                                liberaLS(lista);
                                liberaLC($8);
                            }
                            else
                            {
                                printf("\n%d errores léxicos\n"
                                "%d errores sintácticos\n"
                                "%d errores semánticos\n"
                                "%d errores en la generación "
                                "del código\n", err_lexicos, err_sintacticos, err_semanticos, err_gen_cod);
                            }
                      }
                    ;

functions           : functions function ";"
                    |
                    ;

function            : "function" "id" "(" "const" identifiers ":" type ")" ":" type
                                        declarations compound_statement {
                                                                            liberaLC($11);
                                                                            printf("Error en la línea %d: no se soportan funciones\n",yylineno);
                                                                            err_gen_cod++;
                                                                        }
                    ;

declarations        : declarations "var" identifiers ":" type ";" {
                                                                    if ( ok() )
                                                                        $$ = $1;
                                                                  }
                    | declarations "const" constants ";"{
                                                            if ( ok() )
                                                            {
                                                                $$ = $1;
                                                                concatenaLC($$,$3);
                                                                liberaLC($3);
                                                            }
                                                        }
                    | { $$ = creaLC(); }
                    ;

identifiers         : "id" {
                                /* Comprobar si $1 está en la lista */
                                PosicionLista p = buscaLS(lista, $1);
                                if (p != finalLS(lista))
                                {
                                    /* El identificador está siendo redeclarado */
                                    printf("Error en la línea %d: identificador %s "
                                           "redeclarado\n", yylineno, $1);
                                    err_semanticos++;
                                }
                                else
                                {
                                    /* Primera declaración del identificador, es correcto */
                                    Simbolo s;
                                    s.nombre = $1;
                                    s.tipo = VARIABLE;
                                    insertaLS(lista, p, s);
                                }
                            }
                    | identifiers "," "id"{
                                            /* Comprobar si $3 está en la lista */
                                            PosicionLista p = buscaLS(lista, $3);
                                            if (p != finalLS(lista))
                                            {
                                                /* El identificador está siendo redeclarado */
                                                printf("Error en la línea %d: identificador %s "
                                                        "redeclarado\n", yylineno, $3);
                                                err_semanticos++;
                                            }
                                            else
                                            {
                                                /* Primera declaración del identificador, es correcto */
                                                Simbolo s;
                                                s.nombre = $3;
                                                s.tipo = VARIABLE;
                                                insertaLS(lista, p, s);
                                            }
                                          }
                    ;

type                : "integer"
                    ;

constants           : "id" ":=" expression{
                                            /* Comprobar si $1 está en la lista */
                                            PosicionLista p = buscaLS(lista, $1);
                                            if (p != finalLS(lista))
                                            {
                                                /* El identificador está siendo redeclarado */
                                                printf("Error en la línea %d: identificador %s "
                                                        "redeclarado\n", yylineno, $1);
                                                err_semanticos++;
                                            }
                                            else
                                            {
                                                /* Primera declaración del identificador, es correcto */
                                                Simbolo s;
                                                s.nombre = $1;
                                                s.tipo = CONSTANTE;
                                                insertaLS(lista, finalLS(lista), s);
                                            }
                                            /* En caso de no haber errores previos, generamos código MIPS */
                                            if ( ok() )
                                            {
                                                $$ = $3;
                                                Operacion oper;
                                                oper.op = "sw";
                                                oper.res = recuperaResLC($3);
                                                oper.arg1 = concatena("_",$1);
                                                oper.arg2 = NULL;
                                                insertaLC($$, finalLC($$), oper);
                                                liberarReg(oper.res);
                                            }
                                        }
                    | constants "," "id" ":=" expression{
                                                            /* Comprobar si $3 está en la lista */
                                                            PosicionLista p = buscaLS(lista, $3);
                                                            if (p != finalLS(lista))
                                                            {
                                                                /* El identificador está siendo redeclarado */
                                                                printf("Error en la línea %d: identificador %s "
                                                                        "redeclarado\n", yylineno, $3);
                                                                err_semanticos++;
                                                            }
                                                            else
                                                            {
                                                                /* Primera declaración del identificador, es correcto */
                                                                Simbolo s;
                                                                s.nombre = $3;
                                                                s.tipo = CONSTANTE;
                                                                insertaLS(lista, p, s);
                                                            }
                                                            /* En caso de no haber errores previos, generamos código MIPS */
                                                            if ( ok() )
                                                            {
                                                                $$ = $1;
                                                                concatenaLC($$, $5);
                                                                Operacion oper;
                                                                oper.op = "sw";
                                                                oper.res = recuperaResLC($5);
                                                                oper.arg1 = concatena("_",$3);
                                                                oper.arg2 = NULL;
                                                                insertaLC($$, finalLC($$), oper);
                                                                liberaLC($5);
                                                                liberarReg(oper.res);
                                                            }
                                                        }
                    ;

compound_statement  : "begin" optional_statements "end" {
                                                            if ( ok() )
                                                                $$ = $2;
                                                        }
                    ;

optional_statements : statements {
                                    if ( ok() )
                                        $$ = $1;
                                 }
                    | {
                        if ( ok() )
                            $$ = creaLC();
                      }
                    ;

statements          : statement {
                                    if ( ok() )
                                        $$ = $1;
                                }
                    | statements ";" statement{
                                                if ( ok() )
                                                {
                                                    $$ = $1;
                                                    concatenaLC($$, $3);
                                                    liberaLC($3);
                                                }
                                              }
                    ;

statement           : "id" ":=" expression{
                                            /* Comprobar si $1 está en la lista */
                                            PosicionLista p = buscaLS(lista, $1);
                                            if (p != finalLS(lista))
                                            {
                                                /* Comprobamos que $1 es una constante */
                                                Simbolo s = recuperaLS(lista,p);
                                                if ( s.tipo == CONSTANTE )
                                                {
                                                    /* Se está redefiniendo una constante */
                                                     printf("Error en la línea %d: %s "
                                                        "es una constante \n", yylineno, $1);
                                                    err_semanticos++;
                                                }
                                            }
                                            else
                                            {
                                                /* Identificador sin declaración previa */
                                                printf("Error en la línea %d: "
                                                        "identificador %s no "
                                                        "declarado\n", yylineno, $1);
                                                err_semanticos++;
                                            }
                                            if ( ok() )
                                            {
                                                $$ = $3;
                                                Operacion oper;
                                                oper.op = "sw";
                                                oper.res = recuperaResLC($3);
                                                oper.arg1 = concatena("_",$1);
                                                oper.arg2 = NULL;
                                                insertaLC($$, finalLC($$), oper);
                                                liberarReg(oper.res);
                                            }
                                          }

                    | "if" expression "then" statement{
                                                        if ( ok() )
                                                        {
                                                            $$ = $2;
                                                            /*
                                                                Colocamos la instruccion de salto condicional
                                                                tras el código correspondiente a la expresión
                                                            */
                                                            Operacion oper;
                                                            oper.op = "beqz";
                                                            oper.res = recuperaResLC($$);
                                                            oper.arg1 = nuevaEtiqueta();
                                                            oper.arg2 = NULL;
                                                            insertaLC($$, finalLC($$), oper);
                                                            /*
                                                                Liberamos el registro temporal que contiene
                                                                el resultado de la expresión
                                                            */
                                                            liberarReg(oper.res);

                                                            /*
                                                                Concatenamos el código del statement y liberamos
                                                                su lista de código
                                                            */
                                                            concatenaLC($$, $4);
                                                            liberaLC($4);

                                                            /* Colocamos la etiqueta por si falla la condición */
                                                            oper.op = "etiq";
                                                            oper.res = oper.arg1;
                                                            oper.arg1 = NULL;
                                                            oper.arg2 = NULL;
                                                            insertaLC($$, finalLC($$), oper);
                                                        }
                                                      }
                    | "if" expression "then" statement "else" statement{
                                                                        if ( ok() )
                                                                        {
                                                                            $$ = $2;
                                                                            /*
                                                                                Colocamos la instruccion de salto condicional
                                                                                tras el código correspondiente a la expresión
                                                                            */
                                                                            Operacion oper;
                                                                            oper.op = "beqz";
                                                                            oper.res = recuperaResLC($$);
                                                                            /*
                                                                                Guardamos la etiqueta, ya que la necesitaremos
                                                                                más adelante
                                                                            */
                                                                            char* et1 = nuevaEtiqueta();
                                                                            oper.arg1 = et1;
                                                                            oper.arg2 = NULL;
                                                                            insertaLC($$, finalLC($$), oper);
                                                                            liberarReg(oper.res);

                                                                            concatenaLC($$, $4);
                                                                            liberaLC($4);

                                                                            /* Salto incondicional para no ejecutar el segundo statement */
                                                                            oper.op = "b";
                                                                            /* Guardamos la etiqueta para no sobreescribirla */
                                                                            char* et2 = nuevaEtiqueta();
                                                                            oper.res = et2;
                                                                            oper.arg1 = NULL;
                                                                            oper.arg2 = NULL;
                                                                            insertaLC($$, finalLC($$), oper);

                                                                            /* Insertamos la primera etiqueta */
                                                                            oper.op = "etiq";
                                                                            oper.res = et1;
                                                                            oper.arg1 = NULL;
                                                                            oper.arg2 = NULL;
                                                                            insertaLC($$, finalLC($$), oper);

                                                                            /* Concatenamos el código del segundo statement */
                                                                            concatenaLC($$,$6);
                                                                            liberaLC($6);

                                                                            /* Insertamos la segunda etiqueta */
                                                                            oper.op = "etiq";
                                                                            oper.res = et2;
                                                                            oper.arg1 = NULL;
                                                                            oper.arg2 = NULL;
                                                                            insertaLC($$, finalLC($$), oper);
                                                                        }
                                                                       }
                    | "while" expression "do" statement{
                                                            if ( ok() )
                                                            {
                                                                $$ = $2;
                                                                Operacion oper;
                                                                oper.op = "etiq";
                                                                /*
                                                                    Guardamos la etiqueta, ya que la necesitaremos
                                                                    más adelante
                                                                */
                                                                char* et1 = nuevaEtiqueta();
                                                                oper.res = et1;
                                                                oper.arg1 = NULL;
                                                                oper.arg2 = NULL;
                                                                insertaLC($$, inicioLC($$), oper);

                                                                /* Condición del while */
                                                                oper.op = "beqz";
                                                                oper.res = recuperaResLC($2);
                                                                /* Guardamos la etiqueta */
                                                                char* et2 = nuevaEtiqueta();
                                                                oper.arg1 = et2;
                                                                oper.arg2 = NULL;
                                                                insertaLC($$, finalLC($$), oper);

                                                                /* Concatenamos el código del statement */
                                                                concatenaLC($$, $4);
                                                                liberaLC($4);

                                                                /* Salto incondicional a la comprobación del while */
                                                                oper.op = "b";
                                                                oper.res = et1;
                                                                oper.arg1 = NULL;
                                                                oper.arg2 = NULL;
                                                                insertaLC($$, finalLC($$), oper);

                                                                /* Insertamos la segunda etiqueta */
                                                                oper.op = "etiq";
                                                                oper.res = et2;
                                                                oper.arg1 = NULL;
                                                                oper.arg2 = NULL;
                                                                insertaLC($$, finalLC($$), oper);

                                                                liberarReg(recuperaResLC($2));
                                                            }
                                                       }
                    | "for" "id" ":=" expression "to" expression "do" statement{
                                                                                /* Comprobamos si $2 ya está en la lista */
                                                                                PosicionLista p = buscaLS(lista, $2);
                                                                                if (p != finalLS(lista))
                                                                                {
                                                                                    /* Comprobamos si $2 es una constante */
                                                                                    Simbolo s = recuperaLS(lista,p);
                                                                                    if ( s.tipo == CONSTANTE )
                                                                                    {
                                                                                        /* Redefinición de una constante */
                                                                                        printf("Error en la línea %d: %s "
                                                                                            "es una constante \n", yylineno, $2);
                                                                                        err_semanticos++;
                                                                                    }
                                                                                }
                                                                                else
                                                                                {
                                                                                    /* Identificador sin declarar */
                                                                                    printf("Error en la línea %d: "
                                                                                            "identificador %s no "
                                                                                            "declarado\n", yylineno, $2);
                                                                                    err_semanticos++;
                                                                                }
                                                                                if ( ok() )
                                                                                {
                                                                                    $$ = $4;
                                                                                    /* Almacenamos el resultado de la expresión en memoria */
                                                                                    Operacion oper;
                                                                                    oper.op = "sw";
                                                                                    oper.res = recuperaResLC($4);
                                                                                    oper.arg1 = concatena("_",$2);
                                                                                    oper.arg2 = NULL;
                                                                                    insertaLC($$, finalLC($$), oper);
                                                                                    liberarReg(oper.res);

                                                                                    /*
                                                                                        Concatenamos el código de la segunda expresión,
                                                                                        no liberamos aún su lista de código, con esto hacemos
                                                                                        que el acceso al valor que retorna sea más sencillo
                                                                                    */
                                                                                    concatenaLC($$, $6);

                                                                                    /* Insertamos la etiqueta que precede a la comprobación */
                                                                                    oper.op = "etiq";
                                                                                    char* et1 = nuevaEtiqueta();
                                                                                    oper.res = et1;
                                                                                    oper.arg1 = NULL;
                                                                                    oper.arg2 = NULL;
                                                                                    insertaLC($$, finalLC($$), oper);

                                                                                    /*
                                                                                        Cargamos el valor de la variable de control
                                                                                        en un registro temporal para poder hacer la
                                                                                        comprobación
                                                                                    */
                                                                                    oper.op = "lw";
                                                                                    oper.res = obtenerReg();
                                                                                    oper.arg1 = concatena("_",$2);
                                                                                    oper.arg2 = NULL;
                                                                                    insertaLC($$, finalLC($$), oper);

                                                                                    /* Comprobamos la condición de salto */
                                                                                    oper.op = "bgt";
                                                                                    /* oper.res mantiene su valor */
                                                                                    oper.arg1 = recuperaResLC($6);
                                                                                    char* et2 = nuevaEtiqueta();
                                                                                    oper.arg2 = et2;
                                                                                    insertaLC($$, finalLC($$), oper);
                                                                                    /* Liberamos registro (Decisión explicada en memoria) */
                                                                                    liberarReg(oper.res);

                                                                                    /*
                                                                                        Concatenamos el código del statement y
                                                                                        liberamos su lista de código
                                                                                    */
                                                                                    concatenaLC($$, $8);
                                                                                    liberaLC($8);

                                                                                    /*
                                                                                        Cargamos el valor de la variable de control en
                                                                                        un registro temporal para poder hacer el incremento
                                                                                    */
                                                                                    oper.op = "lw";
                                                                                    oper.res = obtenerReg();
                                                                                    oper.arg1 = concatena("_",$2);
                                                                                    oper.arg2 = NULL;
                                                                                    insertaLC($$, finalLC($$), oper);

                                                                                    /* Realizamos el incremento */
                                                                                    oper.op = "addi";
                                                                                    /* oper.res mantiene su valor */
                                                                                    oper.arg1 = oper.res;
                                                                                    oper.arg2 = "1";
                                                                                    insertaLC($$, finalLC($$), oper);

                                                                                    /* Almacenamos en memoria el valor del registro */
                                                                                    oper.op = "sw";
                                                                                    /* oper.res mantiene su valor */
                                                                                    oper.arg1 = concatena("_",$2);
                                                                                    oper.arg2 = NULL;
                                                                                    insertaLC($$, finalLC($$), oper);
                                                                                    /* Liberamos de nuevo el registro temporal */
                                                                                    liberarReg(oper.res);

                                                                                    /* Salto incondicional a la comprobación del for*/
                                                                                    oper.op = "b";
                                                                                    oper.res = et1;
                                                                                    oper.arg1 = NULL;
                                                                                    oper.arg2 = NULL;
                                                                                    insertaLC($$, finalLC($$), oper);

                                                                                    /* Etiqueta final */
                                                                                    oper.op = "etiq";
                                                                                    oper.res = et2;
                                                                                    oper.arg1 = NULL;
                                                                                    oper.arg2 = NULL;
                                                                                    insertaLC($$, finalLC($$), oper);

                                                                                    /*
                                                                                        Liberamos el registro temporal de
                                                                                        $6 y su lista de código
                                                                                    */
                                                                                    liberarReg(recuperaResLC($6));
                                                                                    liberaLC($6);
                                                                                }
                                                                               }
                    | "write" "(" print_list ")" {
                                                    if ( ok() )
                                                        $$ = $3;
                                                 }
                    | "read" "(" read_list ")" {
                                                    if ( ok() )
                                                        $$ = $3;
                                               }
                    | compound_statement {
                                            if ( ok() )
                                                $$ = $1;
                                         }
                    ;

print_list          : print_item {
                                    if ( ok() )
                                        $$ = $1;
                                 }
                    | print_list "," print_item{
                                                    if ( ok() )
                                                    {
                                                        $$ = $1;
                                                        concatenaLC($$, $3);
                                                        liberaLC($3);
                                                    }
                                               }
                    ;

print_item          : expression{
                                    if ( ok() )
                                    {
                                        $$ = $1;
                                        /* Preparamos el registro $v0 para la correspondiente syscall */
                                        Operacion oper;
                                        oper.op = "li";
                                        oper.res = "$v0";
                                        oper.arg1 = "1";
                                        oper.arg2 = NULL;
                                        insertaLC($$, finalLC($$), oper);

                                        /* Cargamos el valor de la expresión en $a0 */
                                        oper.op = "move";
                                        oper.res = "$a0";
                                        oper.arg1 = recuperaResLC($$);
                                        oper.arg2 = NULL;
                                        insertaLC($$, finalLC($$), oper);
                                        /* Liberamos el registro temporal */
                                        liberarReg(recuperaResLC($$));

                                        /* Hacemos la llamada al sistema */
                                        oper.op = "syscall";
                                        oper.res = NULL;
                                        oper.arg1 = NULL;
                                        oper.arg2 = NULL;
                                        insertaLC($$, finalLC($$), oper);
                                    }
                                }
                    | "string"{
                                /* Comprobar si $1 ya está en la lista */
                                PosicionLista p = buscaLS(lista, $1);
                                if (p == finalLS(lista))
                                {
                                    Simbolo s;
                                    s.nombre = $1;
                                    s.tipo = CADENA;
                                    s.valor = num_string++;
                                    insertaLS(lista, p, s);
                                }
                                if ( ok() )
                                {
                                    /* Creamos la lista de código */
                                    $$ = creaLC();
                                    /*
                                        Preparamos el registro $v0 para la
                                        correspondiente syscall
                                    */
                                    Operacion oper;
                                    oper.op = "li";
                                    oper.res = "$v0";
                                    oper.arg1 = "4";
                                    oper.arg2 = NULL;
                                    insertaLC($$, finalLC($$), oper);

                                    /*
                                        Como ya conocemos la posición del string
                                        en la lista de símbolos la aprovechamos
                                    */
                                    Simbolo s2;
                                    s2 = recuperaLS(lista, p);

                                    /* Cargamos la direccion del string en $a0 */
                                    oper.op = "la";
                                    oper.res = "$a0";
                                    oper.arg1 = concatenaInt("$str",s2.valor);
                                    oper.arg2 = NULL;
                                    insertaLC($$, finalLC($$), oper);

                                    /* Hacemos la llamada al sistema */
                                    oper.op = "syscall";
                                    oper.res = NULL;
                                    oper.arg1 = NULL;
                                    oper.arg2 = NULL;
                                    insertaLC($$, finalLC($$), oper);
                                }
                              }
                    ;

read_list           : "id"{
                            /* Comprobar si $1 ya está en la lista */
                            PosicionLista p = buscaLS(lista, $1);
                            if (p != finalLS(lista))
                            {
                                /* Comprobamos si $1 es una constante */
                                Simbolo s = recuperaLS(lista,p);
                                if ( s.tipo == CONSTANTE )
                                {
                                    /* Redefinición de una constante */
                                        printf("Error en la línea %d: %s "
                                        "es una constante \n", yylineno, $1);
                                    err_semanticos++;
                                }
                            }
                            else
                            {
                                /* Identificador sin declarar */
                                printf("Error en la línea %d: "
                                        "identificador %s no "
                                        "declarado\n", yylineno, $1);
                                err_semanticos++;
                            }
                            if ( ok() )
                            {
                                $$ = creaLC();
                                /* Preparamos el registro $v0 para la correspondiente syscall */
                                Operacion oper;
                                oper.op = "li";
                                oper.res = "$v0";
                                oper.arg1 = "5";
                                oper.arg2 = NULL;
                                insertaLC($$, finalLC($$), oper);

                                /* Hacemos la llamada al sistema */
                                oper.op = "syscall";
                                oper.res = NULL;
                                oper.arg1 = NULL;
                                oper.arg2 = NULL;
                                insertaLC($$, finalLC($$), oper);

                                /* Almacenamos el valor leído en la variable */
                                oper.op = "sw";
                                oper.res = "$v0";
                                oper.arg1 = concatena("_",$1);
                                oper.arg2 = NULL;
                                insertaLC($$, finalLC($$), oper);
                            }
                          }
                    | read_list "," "id"{
                                            /* Comprobar si $3 ya está en la lista */
                                            PosicionLista p = buscaLS(lista, $3);
                                            if (p != finalLS(lista))
                                            {
                                                /* Comprobamos si $3 es una constante */
                                                Simbolo s = recuperaLS(lista,p);
                                                if ( s.tipo == CONSTANTE )
                                                {
                                                    /* Redefinición de una constante */
                                                        printf("Error en la línea %d: %s "
                                                        "es una constante \n", yylineno, $3);
                                                    err_semanticos++;
                                                }
                                            }
                                            else
                                            {
                                                /* Identificador sin declarar */
                                                printf("Error en la línea %d: "
                                                        "identificador %s no "
                                                        "declarado\n", yylineno, $3);
                                                err_semanticos++;
                                            }
                                            if ( ok() )
                                            {
                                                $$ = $1;
                                                /* Preparamos el registro $v0 para la correspondiente syscall */
                                                Operacion oper;
                                                oper.op = "li";
                                                oper.res = "$v0";
                                                oper.arg1 = "5";
                                                oper.arg2 = NULL;
                                                insertaLC($$, finalLC($$), oper);

                                                /*  Realizamos la llamada al sistema */
                                                oper.op = "syscall";
                                                oper.res = NULL;
                                                oper.arg1 = NULL;
                                                oper.arg2 = NULL;
                                                insertaLC($$, finalLC($$), oper);

                                                /* Almacenamos el valor leído en la variable */
                                                oper.op = "sw";
                                                oper.res = "$v0";
                                                oper.arg1 = concatena("_",$3);
                                                oper.arg2 = NULL;
                                                insertaLC($$, finalLC($$), oper);
                                            }
                                        }
                    ;

expression          : expression "+" expression {
                                                    if ( ok() )
                                                    {
                                                        /*
                                                            Concatenamos el código de ambas operaciones
                                                            tras esto, añadimos el código correspondiente a
                                                            la suma
                                                        */
                                                        $$ = $1;
                                                        concatenaLC($$, $3);
                                                        Operacion oper;
                                                        oper.op = "add";
                                                        oper.res = recuperaResLC($1);
                                                        oper.arg1 = recuperaResLC($1);
                                                        oper.arg2 = recuperaResLC($3);
                                                        insertaLC($$, finalLC($$), oper);
                                                        /*
                                                            Liberamos el registro temporal y la lista de código
                                                            de la segunda expresión.
                                                            No se libera el registro de la primera expresión, pues
                                                            lo utilizamos para almacenar el resultado de la operación
                                                        */
                                                        liberarReg(oper.arg2);
                                                        liberaLC($3);
                                                    }
                                                }
                    | expression "-" expression {
                                                    if ( ok() )
                                                    {
                                                        /*
                                                            Concatenamos el código de ambas operaciones
                                                            tras esto, añadimos el código correspondiente a
                                                            la resta
                                                        */
                                                        $$ = $1;
                                                        concatenaLC($$, $3);
                                                        Operacion oper;
                                                        oper.op = "sub";
                                                        oper.res = recuperaResLC($1);
                                                        oper.arg1 = recuperaResLC($1);
                                                        oper.arg2 = recuperaResLC($3);
                                                        insertaLC($$, finalLC($$), oper);
                                                        liberaLC($3);
                                                        liberarReg(oper.arg2);
                                                    }
                                                }
                    | expression "*" expression {
                                                    if ( ok() )
                                                    {
                                                        /*
                                                            Concatenamos el código de ambas operaciones
                                                            tras esto, añadimos el código correspondiente al
                                                            producto
                                                        */
                                                        $$ = $1;
                                                        concatenaLC($$, $3);
                                                        Operacion oper;
                                                        oper.op = "mul";
                                                        oper.res = recuperaResLC($1);
                                                        oper.arg1 = recuperaResLC($1);
                                                        oper.arg2 = recuperaResLC($3);
                                                        insertaLC($$, finalLC($$), oper);
                                                        liberaLC($3);
                                                        liberarReg(oper.arg2);
                                                    }
                                                }
                    | expression "/" expression {
                                                    if ( ok() )
                                                    {
                                                        /*
                                                            Concatenamos el código de ambas operaciones
                                                            tras esto, añadimos el código correspondiente al
                                                            cociente
                                                        */
                                                        $$ = $1;
                                                        concatenaLC($$, $3);
                                                        Operacion oper;
                                                        oper.op = "div";
                                                        oper.res = recuperaResLC($1);
                                                        oper.arg1 = recuperaResLC($1);
                                                        oper.arg2 = recuperaResLC($3);
                                                        insertaLC($$, finalLC($$), oper);
                                                        liberaLC($3);
                                                        liberarReg(oper.arg2);
                                                    }
                                                }
                    | "-" expression %prec UMENOS {
                                                    if ( ok() )
                                                    {
                                                        /*
                                                            Concatenamos el código de ambas operaciones
                                                            tras esto, añadimos el código correspondiente al
                                                            cambio de signo
                                                        */
                                                        $$ = $2;
                                                        Operacion oper;
                                                        oper.op = "neg";
                                                        oper.res = recuperaResLC($2);
                                                        oper.arg1 = recuperaResLC($2);
                                                        oper.arg2 = NULL;
                                                        insertaLC($$, finalLC($$), oper);
                                                    }
                                                  }
                    | "(" expression ")" {
                                            if ( ok() )
                                                $$ = $2;
                                         }
                    | "id"{
                            /* Comprobar si $1 está en la lista */
                            PosicionLista p = buscaLS(lista, $1);
                            if (p == finalLS(lista))
                            {
                                /* Identificador sin declarar */
                                printf("Error en la línea %d: "
                                        "identificador %s no "
                                        "declarado\n", yylineno, $1);
                                err_semanticos++;
                            }
                            if ( ok() )
                            {
                                /*
                                    Asignamos a la expresión el valor de la
                                    variable o constante
                                */
                                $$ = creaLC();
                                Operacion oper;
                                oper.op ="lw";
                                oper.res = obtenerReg();
                                oper.arg1 = concatena("_",$1);
                                oper.arg2 = NULL;
                                insertaLC($$, finalLC($$), oper);
                                guardaResLC($$, oper.res);
                            }
                          }
                    | "num"{
                                if ( ok() )
                                {
                                    $$ = creaLC();
                                    Operacion oper;
                                    oper.op = "li";
                                    oper.res = obtenerReg();
                                    oper.arg1 = $1;
                                    oper.arg2 = NULL;
                                    insertaLC($$, finalLC($$), oper);
                                    guardaResLC($$, oper.res);
                                }
                           }
                    | "id" "(" arguments ")" {
                                                printf("Error, No se soportan funciones\n");
                                                err_gen_cod++;
                                             }
                    ;

arguments           : expressions
                    |
                    ;

expressions         : expression {
                                    liberarReg(recuperaResLC($1));
                                    liberaLC($1);
                                 }
                    | expressions "," expression {
                                                    liberarReg(recuperaResLC($3));
                                                    liberaLC($3);
                                                 }
                    ;

%%
/*
    Redefinición de la función yyerror
*/
void yyerror(const char *msg)
{
    printf("Error en la línea %d: %s\n", yylineno, msg);
    err_sintacticos++;
    printf("\n%d errores léxicos\n"
           "%d errores sintácticos\n"
           "%d errores semánticos\n"
           "%d errores en la generación "
           "del código\n", err_lexicos, err_sintacticos, err_semanticos, err_gen_cod);
}

/*
    Función auxiliar para comprobar si se ha producido algún error
    de cualquier tipo a lo largo del código
*/
int ok ()
{
    return !(err_lexicos + err_semanticos + err_sintacticos + err_gen_cod);
}

/*
    Función en la que nos apoyaremos para escribir en el formato adecuado
    la sección .data del código MIPS
*/
void imprimirLS()
{
    Simbolo s;
    PosicionLista p = inicioLS(lista);

    printf("#Sección de datos\n"
           "\t.data\n");

    while (p != finalLS(lista))
    {
        s = recuperaLS(lista, p);
        if (s.tipo == VARIABLE || s.tipo == CONSTANTE) {
            printf("_%s:\n\t.word 0\n",s.nombre);
        }
        else if (s.tipo == CADENA) {
            printf("$str%d:\n\t.asciiz %s\n", s.valor, s.nombre);
        }
        p = siguienteLS(lista, p);
    }
}

/*
    Función en la que nos apoyaremos para escribir en el formato adecuado
    la parte principal de nuestro código MIPS

    Recibe como parámetro la lista de código a imprimir
*/
void imprimirLC(ListaC listaC)
{
    Operacion oper;
    PosicionListaC p = inicioLC(listaC);
    printf("\n#Sección de código\n"
           "\t.text\n"
           "\t.globl main\n"
           "main:\n");
    while (p != finalLC(listaC))
    {
        oper = recuperaLC(listaC, p);
        if (oper.op == "etiq")
            printf("%s:\n", oper.res);
        else
        {
            printf("\t%s", oper.op);
            if (oper.res) printf(" %s",oper.res);
            if (oper.arg1) printf(", %s",oper.arg1);
            if (oper.arg2) printf(", %s",oper.arg2);
            printf("\n");
        }
        p = siguienteLC(listaC, p);
    }
    printf("#Fin\n"
          "\tjr $ra\n");
}

/*
    Función auxiliar que nos devuelve el menor registro temporal
    libre, en caso de que no se encuentre ninguno disponible
    se lanza un error y se detiene la ejecución del programa
*/
char* obtenerReg()
{
    for(int i = 0; i < 10; i++)
    {
        if(temp[i] == 0)
        {
            temp[i] = 1;
            char aux[4];
            sprintf(aux, "$t%d", i);
            return strdup(aux);
        }
    }
    printf("Error: registros agotados\n");
    exit(1);
}

/*
    Función auxiliar para la liberación de un resgistro temporal

    Recibe como parámetro el registro temporal que se desea liberar
*/
void liberarReg(char* reg)
{
    if((reg[0]=='$') && (reg[1]=='t'))
    {
        int aux = reg[2]-'0';
        assert(aux >= 0);
        assert(aux < 10);
        temp[aux] = 0;
    }
}

/*
    Función auxiliar que recibe como parámetro dos strings y retorna
    la concatenación de estos

*/
char* concatena (char* arg1, char* arg2)
{
    char* aux = (char*) malloc(strlen(arg1) + strlen(arg2) + 1);
    sprintf(aux, "%s%s", arg1, arg2);
    return aux;
}

/*
    Misma funcionalidad que concatena, con la salvedad de recibir un
    entero como segundo parámetro
*/
char* concatenaInt (char* arg1, int valor)
{
    char* aux = (char*) malloc(strlen(arg1) + 11); //TODO cuantos strings se permiten?
    sprintf(aux, "%s%d", arg1, valor);
    return aux;
}

/*
    Función auxiliar que nos devuelve un nuevo identificador para una etiqueta
*/
char* nuevaEtiqueta()
{
    char aux[16];
    sprintf(aux,"$l%d", contador_etiq++);
    return strdup(aux);
}