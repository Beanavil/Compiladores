%{
#include "sintactico.tab.h"
#include <math.h>
int inicio_coment = 0;
int err_lexicos = 0;
%}
digito              [0-9]
letra               [a-zA-Z]
entero              {digito}+
panico              [^ \n\t\ra-zA-Z_0-9(){};,=+\-"]

/* Condición de contexto */
%x COMENT

/* Opción para disponer de número de línea */
%option yylineno

%%
[ \n\t]+                                    ;
"//"(.*)[\n]                                ;
"(*"                                        {
                                                inicio_coment = yylineno;
                                                BEGIN(COMENT);
                                                yymore();
                                            }
<COMENT>"*)"                                {
                                                BEGIN(INITIAL);
                                            }
<COMENT>.|\n                                yymore();
<COMENT><<EOF>>                             {
                                                printf("Error comentario sin cerrar\n");
                                                err_lexicos++;
                                                return 0;
                                            }
main                                        return MAIN;
program                                     return PROGRAM;
function                                    return FUNCTION;
const                                       return CONST;
var                                         return VAR;
integer                                     return INTEGER;
begin                                       return BEGINN;
end                                         return END;
if                                          return IF;
then                                        return THEN;
else                                        return ELSE;
while                                       return WHILE;
do                                          return DO;
for                                         return FOR;
to                                          return TO;
write                                       return WRITE;
read                                        return READ;
({letra}|_)({letra}|{digito}|_)*            {
                                                if( strlen(yytext) > 16 )
                                                {
                                                    printf("Error en la línea %d: el identificador debe contener"
                                                    " menos de 16 caracteres\n", yylineno);
                                                    err_lexicos++;
                                                }
                                                yylval.str = strdup(yytext);
                                                return IDENT;
                                            }
{entero}                                    {
                                                if((atoll(yytext)  > pow(2,31)) || (atoll(yytext)  < -pow(2,31)))
                                                {
                                                    printf("Error en la línea %d: el valor absoluto de cada entero "
                                                    "debe ser menor que pow(2,31)\n", yylineno);
                                                    err_lexicos++;
                                                }
                                                yylval.str = strdup(yytext);
                                                return ENTERO;
                                            }
";"                                         return SEMICOLON;
":"                                         return COLON;
"."                                         return DOT;
","                                         return COMMA;
"+"                                         return PLUSOP;
"-"                                         return MINUSOP;
"*"                                         return STAR;
"/"                                         return SLASH;
"("                                         return LPAREN;
")"                                         return RPAREN;
":="                                        return ASSIGNOP;
\"([^\n"]|\\\")*\"                          {
                                                yylval.str = strdup(yytext);
                                                return STRING;
                                            }
\"([^\n"]|\\\")*                            {
                                                printf("Error en la línea %d: comillas sin cerrar: %s\n", yylineno, yytext);
                                                err_lexicos++;
                                            }
{panico}+                                   {
                                                printf("Error en la línea %d: carácter %s inválido\n", yylineno, yytext );
                                                err_lexicos++;
                                            }
%%