mini_pascal : main.c sintactico.tab.c lexico.c listaSimbolos.c listaCodigo.c
	gcc main.c sintactico.tab.c lexico.c listaSimbolos.c listaCodigo.c -lfl -o mini_pascal

lexico.c : lexico.l sintactico.tab.h
	flex -o lexico.c lexico.l

sintactico.tab.c sintactico.tab.h : sintactico.y
	bison -d sintactico.y

clean :
	rm -f lexico lexico.c sintactico.tab.*

run : mini_pascal entrada.txt
	./mini_pascal entrada.txt > salida.s
