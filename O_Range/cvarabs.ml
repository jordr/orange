
(* cvarabs -- use Frontc CAML  abstract store evaluation and evaluation of expression
*
** Project:	O_Range
** File:	cvarabs.ml
** Version:	1.1
** Date:	11.7.2008
** Author:	Marianne de Michiel
*)
open Cabs
open Cxml
open Cprint
open Cexptostr
open Cvariables
open Constante
open Coutput

let version = "cvarabs Marianne de Michiel"


	type arraySize = NOSIZE | SARRAY of int |MSARRAY of int list

	let listAssosArrayIDsize  =  ref [(" ", NOSIZE)]
	let existAssosArrayIDsize name  = (List.mem_assoc name !listAssosArrayIDsize)
	let setAssosArrayIDsize name size = 
		if existAssosArrayIDsize name = false then listAssosArrayIDsize := List.append   [(name, size)]   !listAssosArrayIDsize 	
	let getAssosArrayIDsize name  = if existAssosArrayIDsize name then (List.assoc name !listAssosArrayIDsize) else NOSIZE

let (alreadyAffectedGlobales: string list ref) = ref []
let (withoutTakingCallIntoAccount: bool ref) = ref false
let (getOnlyBoolAssignment: bool ref) = ref false        
let aAntiDep = ref false
let vDEBUG = ref false
let vEPSILON = ref (VARIABLE("EPSILON"))
let vEPSILONFLOAT = ref (CONSTANT (RCONST_FLOAT 0.000001(*min_float*)))
let vEPSILONINT = ref (VARIABLE("EPSILONINT"))
(*let vEPSILON = ref (CONSTANT (CONST_FLOAT "0.001"))*)
let isIntoSwithch = ref false
let (estDansBoucleLast  : bool ref) = ref true (* to keep only essential rond into fixed point *)
let (estDansBoucle  : bool ref) = ref false
let torename = ref ""

let isLoopOrIFId x =
let resb = 
				if (String.length x > 4) then
				begin
					let var4 = (String.sub x  0 4) in
					let var3 = (String.sub x  0 3) in
					if var3 = "ET-" || var3 = "EF-" ||  var3 = "IF-" || var3 = "tN-" || var4 = "max-" || var4 = "tni-" then true else false
				end
				else if (String.length x > 3) then 
						if (String.sub x  0 3) = "ET-" ||(String.sub x  0 3) = "EF-" ||(String.sub x  0 3) = "IF-" || (String.sub x  0 3) = "tN-" then true else false else false in
resb




let rec remplacerValPar  var nouexp expr =
	match expr with
	NOTHING 					-> NOTHING
	| UNARY (op, exp) 			-> UNARY (op, remplacerValPar   var nouexp exp)
	| BINARY (op, exp1, exp2) 	-> BINARY (op, remplacerValPar   var nouexp exp1, remplacerValPar   var nouexp exp2)
	| QUESTION (exp1, exp2, exp3) ->QUESTION (remplacerValPar   var nouexp exp1, remplacerValPar   var nouexp exp2, remplacerValPar   var nouexp exp3)
	| CALL (exp, args) 			->	CALL (exp, List.map(fun a-> remplacerValPar  var nouexp a)args)
	| VARIABLE (s) 				->	if s = var then nouexp else expr
	| INDEX (n,exp) 			->	INDEX (n, remplacerValPar  var nouexp exp);
	| CAST (typ, exp) ->CAST (typ, remplacerValPar   var nouexp  exp)
	| CONSTANT ( CONST_COMPOUND expsc)  -> CONSTANT ( CONST_COMPOUND ( List.map(fun a-> remplacerValPar  var nouexp a)expsc))
	| COMMA exps 					->	(COMMA ( List.map (fun a -> remplacerValPar  var nouexp a) exps))
	| MEMBEROF (ex, c) 			->  (match nouexp with 
											VARIABLE (v) -> MEMBEROF (remplacerValPar   var nouexp ex,   c) 
										|  	UNARY (MEMOF, VARIABLE(v)) -> MEMBEROF (remplacerValPar   var (VARIABLE(v)) ex,   c) 
					
										|_-> MEMBEROF (remplacerValPar   var nouexp ex,   c) )
	| MEMBEROFPTR (ex, c) 		->	(match nouexp with 
											VARIABLE (v) -> MEMBEROFPTR (remplacerValPar   var nouexp ex,   c) 
										|  	UNARY (ADDROF, VARIABLE(v)) -> MEMBEROFPTR (remplacerValPar   var (VARIABLE(v)) ex,   c) 
					
										|_->  MEMBEROFPTR (remplacerValPar   var nouexp ex,   c) )
	| EXPR_SIZEOF exp -> EXPR_SIZEOF (remplacerValPar   var nouexp exp )
	| EXPR_LINE (expr, _, _) ->
			remplacerValPar   var nouexp  expr
	| _ 						-> 	expr

let rec unionCONSTCOUNPOUND   newconst oldconst =
	match newconst with
	  CONSTANT ( CONST_COMPOUND newexp) ->
			(match oldconst with
			   CONSTANT ( CONST_COMPOUND oldexp) -> CONSTANT ( CONST_COMPOUND (unionC newexp oldexp))
			|_->newconst)
	| VARIABLE ("--NOINIT--")				->	oldconst
	|_->newconst
and unionC newexp oldexp =
if newexp = [] || oldexp = [] then newexp
else
begin
	let (newfirst, newnext) = (List.hd newexp,List.tl newexp) in
	let (oldfirst, oldnext) = (List.hd oldexp,List.tl oldexp) in
	match newfirst with
	VARIABLE ("--NOINIT--")				->	 List.append [oldfirst] (unionC newnext oldnext)
	| CONSTANT ( CONST_COMPOUND expsc)  ->  List.append [unionCONSTCOUNPOUND newfirst oldfirst] (unionC newnext oldnext)
	| _-> List.append [newfirst] (unionC newnext oldnext)

end

let rec hasMinimum   expr =
	match expr with
	NOTHING 					->  	(false, NOTHING,NOTHING)
	| UNARY (op, exp) 			->   hasMinimum    exp 
	| BINARY (op, exp1, exp2) 	-> let (has1, min11,min12)= hasMinimum  exp1 in
									if has1 then 
									begin
										let(has2, min21,min22)= hasMinimum exp2 in if has2 then (false, NOTHING,NOTHING) else (has1, min11,min12)
									end else hasMinimum   exp2
	| QUESTION (_, _, _) ->(false, NOTHING,NOTHING)
	| CALL (VARIABLE(v), args) 	->	if v  = "MINIMUM" then (true, List.hd args, List.hd (List.tl args))
									else if v = "partieEntiereInf" then hasMinimum   (List.hd args) else(false, NOTHING,NOTHING)
									
	| VARIABLE (s) 				->	(false, NOTHING,NOTHING)
	| INDEX (n,exp) 			->(false, NOTHING,NOTHING)
	| CAST (typ, exp) ->(false, NOTHING,NOTHING)
	| CONSTANT ( CONST_COMPOUND expsc)  -> (false, NOTHING,NOTHING)
	| COMMA exps 					->(false, NOTHING,NOTHING)
	| MEMBEROF (ex, c) 			->  (false, NOTHING,NOTHING)
	| MEMBEROFPTR (ex, c) 		->	(false, NOTHING,NOTHING)
	| EXPR_SIZEOF exp -> (false, NOTHING,NOTHING)
	| EXPR_LINE (expr, _, _) -> 	hasMinimum expr
	| _ 						-> 	(false, NOTHING,NOTHING)


let rec replaceMinimum   expr  toreplace=
	match expr with
	| UNARY (op, exp) 			->   UNARY (op, replaceMinimum exp  toreplace) 	
	| BINARY (op, exp1, exp2) 	->  BINARY (op, replaceMinimum exp1  toreplace, replaceMinimum exp2  toreplace) 
	| CALL (VARIABLE(v), args) 	->	if v  = "MINIMUM" then if toreplace = 1 then  List.hd args else List.hd (List.tl args)
									else if v = "partieEntiereInf" then replaceMinimum   (List.hd args) toreplace else expr
	| EXPR_LINE (expr, _, _) -> 	replaceMinimum   expr toreplace 
	| _ 						-> 	expr









let rec removeSpecifieur st intType= 
let length = String.length st in
if length > 1 then
begin
	let lCar= String.get st (length-1) in
	let sub = (String.sub st  0 (length-1)) in
	
		 
		if intType then 
			if 	(lCar == 'l' || lCar == 'L') then (  removeSpecifieur (sub) intType) else st
		else if (lCar == 'l' || lCar == 'L' || lCar == 'f' || lCar == 'F') then removeSpecifieur (sub) intType else st
	
end
else st





let rec getArrayNameOfexp exp =
	match exp with
		  UNARY (op, e) ->
			let (tab1,lidx1, e1) =getArrayNameOfexp e in
			(match op with
			  MEMOF | ADDROF -> (tab1,lidx1,  UNARY (op,e1))
			|_->(tab1,lidx1, e1))

		| BINARY (_, exp1, exp2) ->
			let (tab1,lidx1, e1) = getArrayNameOfexp exp1 in
			if tab1 = "" then  getArrayNameOfexp exp2  
			else (tab1,lidx1, e1)
		| CAST (typ, e) -> getArrayNameOfexp e 
		| VARIABLE name -> (name, [], exp)
		| INDEX (exp1, idx) ->let (tab,lidx) = analyseArray exp []  in (tab,lidx, exp)
		|_ ->("", [], NOTHING)

and analyseArray exp lidx =
	match exp with 
		VARIABLE v -> (v , lidx)
		| INDEX (e, i) ->  analyseArray e (List.append [i] lidx) 
		| _ -> (* actuellement  non traitée *)("", lidx)

and analyseArrayIntostruct exp lidx =
	match exp with 
		VARIABLE v -> (exp , lidx)
		| INDEX (e, i) ->  analyseArrayIntostruct e (List.append [i] lidx) 
		| MEMBEROF (e , t) 			
		| MEMBEROFPTR (e , t)  -> (* actuellement  non traitée *)( exp ,lidx) 
		| _ -> (* actuellement  non traitée *)(NOTHING, lidx)



type newBaseType =
	FLOAT_TYPE (*float values*)
	|INT_TYPE
(*	| ENUM_TYPE of string*)
	| UNION_TYPE  of string
	| TYPEDEF_NAME of string
	|  STRUCT_TYPE of string 

let get_estAffect exp =
	match exp with
	BINARY (op, _, _) ->
	( match op with ASSIGN|ADD_ASSIGN|SUB_ASSIGN|MUL_ASSIGN|DIV_ASSIGN|MOD_ASSIGN|BOR_ASSIGN|XOR_ASSIGN|SHL_ASSIGN|SHR_ASSIGN->  true
	  |_ -> false )
	| UNARY (op, _) -> ( match op with		PREINCR | PREDECR 	| POSINCR	| POSDECR ->  true |_ -> false )
	|_ -> false	

type expVA = EXP  of expression |	MULTIPLE

type abstractStore =
		ASSIGN_SIMPLE of string  * expVA
	|	ASSIGN_DOUBLE of string * expVA * expVA
	|   ASSIGN_MEM of string * expVA * expVA 


let new_assign_simple id exp  = ASSIGN_SIMPLE(id, exp)
let new_assign_double id exp1 exp2  = ASSIGN_DOUBLE(id, exp1, exp2)
let new_assign_mem id exp1 exp2  = ASSIGN_MEM (id, exp1, exp2)
let (alreadyEvalFunctionAS: (string * abstractStore list)list ref) = ref []

let add_list_comp   v =  
  alreadyEvalFunctionAS := v :: (!alreadyEvalFunctionAS)

type corpsInfo = 
      CORPS of inst
     | ABSSTORE of abstractStore list
  and    
  inst =
	  VAR of string * expVA		
	| MEMASSIGN of string * expVA * expVA
	| TAB of string * expVA * expVA
	| IFV of expVA * inst 			
	| IFVF of expVA * inst * inst			  
	| BEGIN of inst list 
	| FORV of int*string * expVA * expVA * expVA * expVA *inst 	(*derniere expression nb it*)
	| APPEL of int*inst*(* inst*) string * inst*corpsInfo *string*string
	

(* il  faudra ajouter les struct *)
let new_instVar id exp  = VAR(id, if !isIntoSwithch = false then exp else EXP(NOTHING))
let new_instMem id exp1 exp2  = MEMASSIGN(id, exp1, if !isIntoSwithch = false then exp2  else EXP(NOTHING))
let new_instTab id exp1 exp2  = TAB(id, exp1, if !isIntoSwithch = false then exp2  else EXP(NOTHING))
let new_instIFVF exp inst1 inst2  = IFVF(exp, inst1, inst2)
let new_instIFV exp inst1   = IFV(exp, inst1)
let new_instFOR num id exp1 exp2 exp3 nbIt inst  = FORV(num,id, exp1, exp2, exp3, nbIt, inst)
let new_instBEGIN listeInst  = BEGIN(listeInst)
let new_instAPPEL num instAffectIn nom instAffectSortie corps s = APPEL(num, instAffectIn, nom, instAffectSortie, (CORPS corps), s, "")
let new_instAPPELCOMP num instAffectIn nom instAffectSortie absStore s = APPEL(num, instAffectIn, nom, instAffectSortie, (ABSSTORE absStore), s, "")
type listeDesInst = inst list
let listAssocIdType  = ref []
let listeAssosPtrNameType = ref []

type decType =
STRUCTORUNION of (string*newBaseType) list
| TYPEDEFTYPE of newBaseType

let newDecTypeSTRUCTORUNION l = STRUCTORUNION(l)
let newDecTypeTYPEDEFTYPE n = TYPEDEFTYPE(n)

let listAssosIdTypeTypeDec = ref []



let rec getBaseType t =
match t with
	FLOAT_TYPE |INT_TYPE -> t 
	| UNION_TYPE s -> t
	| TYPEDEF_NAME s->  
		 if (List.mem_assoc s !listAssosIdTypeTypeDec)= true then 
		 begin
			match  (List.assoc s !listAssosIdTypeTypeDec)  with  TYPEDEFTYPE (typ) -> getBaseType typ  | _->t
		 end
		 else t
	|  STRUCT_TYPE s ->  t


let isStructAndGetIt t =
match t with
	FLOAT_TYPE |INT_TYPE ->  (false,t) 
	| UNION_TYPE s ->  (false,t)
	| TYPEDEF_NAME s-> 
		 if (List.mem_assoc s !listAssosIdTypeTypeDec)= true then 
		 begin 
			match  (List.assoc s !listAssosIdTypeTypeDec)  with
					  TYPEDEFTYPE (typ) -> (true, getBaseType typ)  
					|(* _->(false,t)*) STRUCTORUNION _ -> (true, t) (* no union type for the moment LAST REVOIR*)
		 end
		 else (Printf.printf "TYPEDEF_NAME\n"; (false, t))
	|  STRUCT_TYPE s ->   (true,t)




let rec getInitVarFromStruct (exp : expression)   =
	 match exp with
		 VARIABLE name ->  [name] 
		| INDEX (e, _)  -> getInitVarFromStruct e 
		| MEMBEROF (e, c)  | MEMBEROFPTR (e, c) -> List.append (getInitVarFromStruct e) [c]
		| UNARY (op, e) ->
					(match op with 
							ADDROF ->
								(*Printf.printf "getInitVarFromStruct &assign\n";*)
								getInitVarFromStruct e 
							|_->(*Printf.printf "not &assign\n";*)[])
		| _-> []


let rec  equalList lid1 lid2 =
if lid1 = [] && lid2  = [] then true
else if lid1 = [] || lid2 = [] then false
	 else
	 begin
		( List.hd lid1  = List.hd  lid2) && (equalList (List.tl lid1) (List.tl lid2))
	 end

(*	let nee = consCommaExp (VARIABLE(id)) btype [id] lid ne  in*)
let rec consCommaExp front t champlist champlistLookingFor exp  withindex index=
match t with
	FLOAT_TYPE |INT_TYPE  -> 
				if champlistLookingFor = [] then (*front VARIABLE ("NOINIT")*)front
				else
				begin
					let ncl = getInitVarFromStruct front in 
					if equalList ncl champlistLookingFor then 
						if withindex then 
						begin
							
							exp
						end
						else	exp	
					else (*front*)VARIABLE ("--NOINIT--")
				end
	|UNION_TYPE s| TYPEDEF_NAME s->  
		 if (List.mem_assoc s !listAssosIdTypeTypeDec)= true then 
		 begin
			match  (List.assoc s !listAssosIdTypeTypeDec)  with 
				 TYPEDEFTYPE (typ) -> consCommaExp front typ champlist champlistLookingFor exp withindex index | _->(*front VARIABLE ("NOINIT")*) front
		 end
		else (*front VARIABLE ("NOINIT")*)front
	|  STRUCT_TYPE s ->  
		if (List.mem_assoc s !listAssosIdTypeTypeDec)= true then 
		 begin
			match  (List.assoc s !listAssosIdTypeTypeDec)  with  
				STRUCTORUNION (l) -> 
					
							CONSTANT(	CONST_COMPOUND(
									List.map (
									fun(n,t)->  
											 
										  consCommaExp ( MEMBEROF (front, n)) t champlist champlistLookingFor exp   withindex index
									)l  ))
						
				| _->(*frontVARIABLE ("NOINIT")*)front
		 end
		else (*front VARIABLE ("NOINIT")*)front

let rec getconsCommaExp  t  champlistLookingFor lexp =

if champlistLookingFor = [] || lexp = []  then (NOTHING) else 
match t with
	FLOAT_TYPE |INT_TYPE  -> (NOTHING)
	|UNION_TYPE s| TYPEDEF_NAME s->  
		 if (List.mem_assoc s !listAssosIdTypeTypeDec)= true then 
		 begin
			match  (List.assoc s !listAssosIdTypeTypeDec) with  
				TYPEDEFTYPE (typ) -> 
										getconsCommaExp  typ  champlistLookingFor lexp 
				| _->(NOTHING)
		 end
		else (NOTHING)
	|  STRUCT_TYPE s ->  
	 
		if (List.mem_assoc s !listAssosIdTypeTypeDec)= true then 
		 begin
			match  (List.assoc s !listAssosIdTypeTypeDec)  with  
			STRUCTORUNION (l) -> 
				if champlistLookingFor = [] || lexp = [] || l = [] then (NOTHING)
				else
				begin	
					let (champ,suitec,expChamp,suiteexpc) = (List.hd champlistLookingFor,List.tl champlistLookingFor,  List.hd lexp,  List.tl lexp) in
					let ((n,typ),suitedec) = (List.hd l,List.tl l) in
(*Printf.printf "champ=%s, n %s\n"champ n;*)
					if n = champ then
						if  suitec = [] then begin  (*print_expression expChamp 0; new_line();  *)expChamp end(*trouve*)
						else getconsCommaExp  typ  suitec suiteexpc(*dans sous champs*)
					else getNextChamp  champlistLookingFor  suiteexpc suitedec (*dans autre champs*)
				end
				
			| TYPEDEFTYPE (n)->(Printf.printf "not membrer \n"; NOTHING)
		 end
		else (Printf.printf "not def struct\n"; NOTHING)

and getNextChamp lchamps  lexp ldec =
if lchamps = [] || lexp = [] || ldec = [] then (NOTHING)
else
begin	
	let (champ,suitec,expChamp,suiteexpc) = (List.hd lchamps,List.tl lchamps, List.hd lexp,  List.tl lexp) in
	let ((n,typ),suitedec) = (List.hd ldec,List.tl ldec) in
(*Printf.printf "getNextChamp champ=%s, n %s\n"champ n;*)
	if n = champ then
						if  suitec = [] then ( (* print_expression expChamp 0; new_line(); *) expChamp (*trouve*))
						else getconsCommaExp  typ  suitec suiteexpc(*dans sous champs*)
	else getNextChamp  lchamps  suiteexpc suitedec (*dans autre champs*)
end

let rec printfBaseType t=
match t with
	FLOAT_TYPE -> Printf.printf " flottant "
	|INT_TYPE -> Printf.printf " integer "
	| UNION_TYPE s ->  Printf.printf " union of %s" s
	| TYPEDEF_NAME s->  Printf.printf " type of %s" s;
		 if (List.mem_assoc s !listAssosIdTypeTypeDec)= true then 
		 begin
			match  (List.assoc s !listAssosIdTypeTypeDec)  with  TYPEDEFTYPE (typ) -> printfBaseType typ  | _->Printf.printf " inconnu TYPEDEFTYPE"
		 end
	|  STRUCT_TYPE s ->  Printf.printf " struct of %s" s;
		if (List.mem_assoc s !listAssosIdTypeTypeDec)= true then 
		 begin
			match  (List.assoc s !listAssosIdTypeTypeDec)  with  
				STRUCTORUNION (l) -> List.iter (fun(n,t)-> Printf.printf " champ %s type\n" n ; printfBaseType t; new_line() )l  
				| TYPEDEFTYPE (n)->Printf.printf " inconnu \n ";printfBaseType n
		 end
		
let print_expVA e = match e with MULTIPLE -> Printf.printf "MULTIPLEDEF \n"| EXP (e) -> if e = NOTHING then Printf.printf "NOTHING" else print_expression e 0

let rec hasPtrArrayBoundConditionExp e =
match e with
		  UNARY (_, exp) ->hasPtrArrayBoundConditionExp exp 
		| BINARY (_, exp1, exp2) ->
			let (b1,e1, iv1, exp1)= hasPtrArrayBoundConditionExp exp1 in
			let (b2,e2, iv2, exp2 )= hasPtrArrayBoundConditionExp exp2 in
			if b1 && b2 = false then  (b1,e1, iv1, exp1)
			else  if b1 = false && b2 then (b2,e2, iv2, exp2 )  else (false, "", true ,NOTHING) 
		| VARIABLE id -> 
			if (String.length id > 19) then
				if (String.sub id  0 19) = "getvarTailleTabMax_" then
				begin
					let var = String.sub id 19 ((String.length id)-19) in
				(*	Printf.printf "dans hasPtrArrayBoundConditionExp, trouve %s type : \n" var;
					printfBaseType (getBaseType (List.assoc var !listAssocIdType) );*)
				    (true , var,true ,NOTHING)	
				end
				else begin(* Printf.printf "dans hasPtrArrayBoundConditionExp, autre\n" ;*)(false, "",true,NOTHING)  end
			else   (false, "",true,NOTHING) 
		| CALL(VARIABLE("getvarTailleTabMax_"), [e]) -> (*Printf.printf "dans hasPtrArrayBoundConditionExp, autre call\n" ; *)(true, "",false ,e)	 
		| CALL(_, [e]) -> (*Printf.printf "dans hasPtrArrayBoundConditionExp, autre call 2\n" ; *)
					hasPtrArrayBoundConditionExp e 
		| _ ->  (false, "",true ,NOTHING)	

let hasPtrArrayBoundCondition e = match e with MULTIPLE -> (false, "",true,NOTHING) | EXP (e) -> hasPtrArrayBoundConditionExp e 

let estNothing e = match e with MULTIPLE -> 	false | EXP (e) -> 	match e with NOTHING -> true |_-> false


let rec containtNothing e = match e with 
		NOTHING -> true
		| UNARY (_, exp) | CAST (_, exp)| EXPR_SIZEOF exp  | EXPR_LINE (exp, _, _)->containtNothing exp
		| BINARY (_, exp1, exp2) ->containtNothing exp1 || containtNothing exp2
		| QUESTION (exp1, exp2, exp3) ->containtNothing exp1 || containtNothing exp2|| containtNothing exp3
		| CALL (exp, args) ->containtNothing exp||listnothing args
		| COMMA exps ->listnothing exps
		| CONSTANT _ | VARIABLE _ | TYPE_SIZEOF _| MEMBEROF (_, _) | MEMBEROFPTR (_, _) | GNU_BODY (_, _)->false
		| INDEX (exp, idx) ->containtNothing exp || containtNothing idx
and listnothing l = 
if l = [] then false else containtNothing (List.hd l) || listnothing (List.tl l) 

type sens =	CROISSANT|   DECROISSANT|   NONMONOTONE|   CONSTANTE

let printSens s =
match s with
	CROISSANT -> 	Printf.printf "CROISSANT \n"
|   DECROISSANT -> 	Printf.printf "DECROISSANT \n"
|   NONMONOTONE -> 	Printf.printf "NONMONOTONE \n"
|   CONSTANTE -> 	Printf.printf "CONSTANTE \n"

type infoAffich =
{
	conditionA : expVA;
	infA : expVA;
	supA : expVA;
	incA : expVA;
	sensVariationA : sens;
	opA :  binary_operator ;
}

let new_infoAffich c i s incr d o=
{
	conditionA =c;
	infA =i;
	supA =s;
	incA =incr;
	sensVariationA =d;
	opA = o;
} 

let infoaffichNull = ref   NONMONOTONE  

type expressionEvaluee =
	 NOCOMP
	| Boolean of bool
	| Var of string
   	| ConstInt of string
	| ConstFloat of string
	| RConstFloat of float
	| Sum of expressionEvaluee * expressionEvaluee    (* e1 + e2 *)
	| Shr of expressionEvaluee * expressionEvaluee    (* e1 SHR e2 *)
	| Shl of expressionEvaluee * expressionEvaluee    (* e1 SHL e2 *)
   	| Diff of expressionEvaluee * expressionEvaluee   (* e1 - e2 *)
   	| Prod of expressionEvaluee * expressionEvaluee    (* e1 + e2 *)
	| Mod of expressionEvaluee * expressionEvaluee    (* e1 + e2 *)
	| Quot of expressionEvaluee * expressionEvaluee    (* e1 + e2 *)
   	| PartieEntiereSup of expressionEvaluee   (* e1 - e2 *)
   	| PartieEntiereInf of expressionEvaluee   (* e1 * e2 *)
	| Puis of expressionEvaluee * expressionEvaluee    (* e1 ** e2 *)
	| Log of expressionEvaluee
    | Sygma of string * expressionEvaluee *expressionEvaluee * expressionEvaluee (*expression*)  (* e1 / e2 *)
    | Max of string * expressionEvaluee *expressionEvaluee * expressionEvaluee (*expression*)  (* e1 / e2 *)
	| Eq1 of expressionEvaluee  (*si E1 = 1 alors e2 sinon e3*)
	| Maximum of expressionEvaluee * expressionEvaluee (* maximum entre 2 expressions *)
	| Minimum of expressionEvaluee * expressionEvaluee 

let rec expressionEvalueeToExpression exprEvaluee =
match exprEvaluee with
	ConstInt(i) 			->  CONSTANT(CONST_INT(i))
	| 	ConstFloat (f) 		->  CONSTANT(CONST_FLOAT (f))
	| 	RConstFloat (f) 		->  CONSTANT(RCONST_FLOAT (f))
	|	NOCOMP				->	NOTHING 
	|   Boolean (b)			-> if b = true then CONSTANT(CONST_INT("1")) else CONSTANT(CONST_INT("0"))	
	|  	Var (s) 			-> 	VARIABLE(s)
	|  	Sum (f, g)  		-> 	let exp1 = expressionEvalueeToExpression f in
								let exp2 = expressionEvalueeToExpression g in
								if exp1 = NOTHING || exp2 = NOTHING then NOTHING else BINARY (ADD, exp1, exp2) 										
	|  	Shl (f, g)  		-> 	let exp1 = expressionEvalueeToExpression f in
								let exp2 = expressionEvalueeToExpression g in
								if exp1 = NOTHING || exp2 = NOTHING then NOTHING
								else BINARY (DIV, exp1,  CALL (VARIABLE("pow"), List.append [CONSTANT(CONST_INT("2"))] [exp2])) 
	|  	Shr (f, g)  		-> 	let exp1 = expressionEvalueeToExpression f in
								let exp2 = expressionEvalueeToExpression g in
								if exp1 = NOTHING || exp2 = NOTHING then NOTHING
								else BINARY (MUL, exp1, CALL (VARIABLE("pow") , List.append [CONSTANT(CONST_INT("2"))] [exp2])) 
	| 	Diff (f, g) 		-> 	let exp1 = expressionEvalueeToExpression f in
								let exp2 = expressionEvalueeToExpression g in
								if exp1 = NOTHING || exp2 = NOTHING then NOTHING else BINARY (SUB, exp1, exp2) 
	| 	Prod (f, g)  		-> 	let exp1 = expressionEvalueeToExpression f in
								let exp2 = expressionEvalueeToExpression g in
								if exp1 = NOTHING || exp2 = NOTHING then NOTHING else BINARY (MUL, exp1, exp2) 
	| 	Mod (f, g)  		-> 	let exp1 = expressionEvalueeToExpression f in
								let exp2 = expressionEvalueeToExpression g in
								if exp1 = NOTHING || exp2 = NOTHING then NOTHING else BINARY (MOD, exp1, exp2) 	
	| 	Quot (f, g)  		-> 	let exp1 = expressionEvalueeToExpression f in
								let exp2 = expressionEvalueeToExpression g in
								if exp1 = NOTHING || exp2 = NOTHING then NOTHING else BINARY (DIV, exp1, exp2) 
	| 	Puis (f, g)  		-> 	let exp1 = expressionEvalueeToExpression f in
								let exp2 = expressionEvalueeToExpression g in
								if exp1 = NOTHING || exp2 = NOTHING then NOTHING else CALL (VARIABLE("pow") , List.append [exp1] [exp2])
	| 	PartieEntiereSup (e)-> 	let exp1 = expressionEvalueeToExpression e in
								if exp1 = NOTHING  then NOTHING else CALL (VARIABLE("partieEntiereSup") , [exp1])
	| 	PartieEntiereInf (e)-> 	let exp1 = expressionEvalueeToExpression e in
								if exp1 = NOTHING then NOTHING else CALL (VARIABLE("partieEntiereInf") , [exp1])
	| 	Log (e)				-> 	let exp1 = expressionEvalueeToExpression e in
								if exp1 = NOTHING  then NOTHING else CALL (VARIABLE("log") , [exp1])
   	| 	Sygma (var,min,max,e)->  let exp1 = expressionEvalueeToExpression max in
								let exp2 = expressionEvalueeToExpression e in
								if exp1 = NOTHING || exp2 = NOTHING then NOTHING
								else CALL (VARIABLE("SYGMA"), List.append[VARIABLE (var)] (List.append [exp1] [exp2]))
   	| 	Max (var,min,max,e)	-> 	let exp1 = expressionEvalueeToExpression max in
								let exp2 = expressionEvalueeToExpression e in
								if exp1 = NOTHING || exp2 = NOTHING then NOTHING
								else CALL (VARIABLE("MAX"), List.append[VARIABLE (var)] (List.append [exp1] [exp2]))
	|  Eq1 (e1) -> 				let exp1 = expressionEvalueeToExpression e1 in
								if exp1 = NOTHING then NOTHING else BINARY(EQ, exp1, CONSTANT(CONST_INT("1")))
	|  Maximum (f, g)  		-> 	let exp1 = expressionEvalueeToExpression f in
								let exp2 = expressionEvalueeToExpression g in
								if exp1 = NOTHING || exp2 = NOTHING then NOTHING else CALL (VARIABLE("MAXIMUM") , (List.append [exp1] [exp2] ))	

	|  Minimum (f, g)  		-> 	let exp1 = expressionEvalueeToExpression f in
								let exp2 = expressionEvalueeToExpression g in
								if exp1 = NOTHING || exp2 = NOTHING then NOTHING else CALL (VARIABLE("MINIMUM") , (List.append [exp1] [exp2] ))	

let estNoComp expr = match expr with NOCOMP	 | 	Sygma (_,_,_,_) | 	Max (_,_,_,_)-> true 
| 	ConstInt(i) 		-> if i = "" then true else false
| 	ConstFloat (f) 			-> if f = "" then true else false 
| 	_-> false

let rec print_expTerm	exprEvaluee =
	match exprEvaluee with
			ConstInt(i) 			->  Printf.printf " %s" i
		| 	ConstFloat (f) 			-> 	Printf.printf " %s" f
		| 	RConstFloat (f) 			-> 	Printf.printf " %g" f
		|	NOCOMP					->	Printf.printf " NOCOMP" 		
		|   Boolean(b)				->  if b = true then Printf.printf " true" 	else Printf.printf " false" 	
		|  	Var (s) 				-> 	Printf.printf " %s" s
		|  	Sum (f, g)  			-> 	Printf.printf "("; print_expTerm f; Printf.printf ") + ("; 
										print_expTerm g; Printf.printf ")"
		|  	Shl (f, g)  			-> 	Printf.printf "("; print_expTerm f; Printf.printf ") << ("; 
										print_expTerm g; Printf.printf ")"
		|  	Shr (f, g)  			-> 	Printf.printf "("; print_expTerm f; Printf.printf ") >> ("; 
										print_expTerm g; Printf.printf ")"
		| 	Diff (f, g)  			-> 	Printf.printf "("; print_expTerm f; Printf.printf ") - ("; 
										print_expTerm g; Printf.printf ")"
		| 	Prod (f, g)  			-> 	Printf.printf "("; print_expTerm f; Printf.printf ") * ("; 
										print_expTerm g; Printf.printf ")"
		| 	Mod (f, g)  			-> 	Printf.printf "("; print_expTerm f; Printf.printf ") Mod ("; 
							  	 		print_expTerm g; Printf.printf ")"
		| 	Quot (f, g)  			-> 	Printf.printf "("; print_expTerm f; Printf.printf ") / ("; 
										print_expTerm g; Printf.printf ")"
		| 	Puis (f, g)  			-> 	Printf.printf "("; print_expTerm f; Printf.printf ") ** ("; 
										print_expTerm g; Printf.printf ")"
		| 	PartieEntiereSup (e)	-> 	Printf.printf "PartieEntiereSup ("; print_expTerm e; Printf.printf ")"
	    | 	PartieEntiereInf (e)	-> 	Printf.printf "PartieEntiereInf ("; print_expTerm e; Printf.printf ")"
		| 	Log (e)					-> 	Printf.printf "Log ("; print_expTerm e; Printf.printf ")"
   		| 	Sygma (var,min,max,e)	-> Printf.printf " NOCOMP" ;	
										if !vDEBUG then
										begin
											Printf.printf "SYGMA pour %s = " var ;print_expTerm min;
											Printf.printf "à " ; print_expTerm max; 
											Printf.printf " (" ;print_expTerm e; Printf.printf ")"
										end
   		| 	Max (var,min,max,e)		->  Printf.printf " NOCOMP" ;	
									if !vDEBUG then
									begin
										Printf.printf "SYGMA pour %s = " var ;print_expTerm min;
										Printf.printf "à " ; print_expTerm max; 
										Printf.printf " (" ;print_expTerm e; Printf.printf ")"
									end
		| 	Eq1 (e1)-> 			Printf.printf " Val TEST " ;	
								print_expTerm e1; Printf.printf " else  " 
		|  Maximum (f, g)  	-> 	Printf.printf " maximum( " ;	print_expTerm f;Printf.printf ", " ;
								print_expTerm g; Printf.printf " ) " 
		|  Minimum (f, g)  	-> 	Printf.printf " minimum( " ;	print_expTerm f;Printf.printf ", " ;
								print_expTerm g; Printf.printf " ) " 	


let rec epsIsonlyVar exp = 
	match exp with
			ConstInt(_) | 	ConstFloat (_) |	NOCOMP	|   Boolean(_)	->   true 
		| 	RConstFloat (_)->   true 
		|  	Var (s) 				-> 	if s = "EPSILON" || s = "EPSILONINT" then true else false (*MARQUE*)
		|  	Sum (f, g) |Shl (f, g) | Shr (f, g) | Diff (f, g)| Prod (f, g)| Mod (f, g)| Quot (f, g) | Puis (f, g)| Maximum (f, g)| Minimum (f, g)  	
				-> 	(epsIsonlyVar) f && (epsIsonlyVar g)
		| 	PartieEntiereSup (e) | 	PartieEntiereInf (e)| 	Log (e)| 	Eq1 (e)	-> epsIsonlyVar e
   		| _	-> false

let espIsNotOnlyVar exp = epsIsonlyVar exp = false   		

let estNul exp =	
	match exp with 
	ConstInt (i)->   (int_of_string  i) = 0 
	|ConstFloat (i) ->  (float_of_string  i) = 0.0|RConstFloat (i) ->  i = 0.0  | _->false
					
let estPositif exp =
	match exp with ConstInt (i)->  (int_of_string  i) >= 0 
	| ConstFloat (i) ->  (float_of_string  i) >= 0.0 | RConstFloat (i) ->  i>= 0.0  | _->false

let estStricPositif exp =
	match exp with 
	 ConstInt (i)-> (int_of_string  i) > 0 
	| ConstFloat (i) ->   (float_of_string  i) > 0.0 | RConstFloat (i) ->   i > 0.0 | _->false

let estUn exp =
	match exp with 
	 ConstInt (i)-> (int_of_string  i) = 1 
	| ConstFloat (i) ->   (float_of_string  i) > 1.0 | RConstFloat (i) ->  i > 1.0 | _->false

let estMUn exp =
	match exp with 
	 ConstInt (i)-> (int_of_string  i) = -1 
	| ConstFloat (i) ->   (float_of_string  i) > -1.0 | RConstFloat (i) ->   i > -1.0 | _->false

let estStricNegatif exp =
	match exp with 
	 ConstInt (i)-> (int_of_string  i) < 0 
	| ConstFloat (i) ->   (float_of_string  i) < 0.0| RConstFloat (i) ->   i < 0.0  | _->false

let rec estInt exp =
	match exp with 
	 ConstInt (_)	-> 	true
	| ConstFloat (f)->  if (floor (float_of_string f)) = (float_of_string f)  then true else false 
	| RConstFloat (f)->  if (floor ( f)) = ( f)  then true else false 
	|  	Var (s) 	-> 	if s = "EPSILON" || s = "EPSILONINT"  then true (*MARQUE*)
						else 
						begin 
							if (List.mem_assoc s !listAssocIdType)= true then 
							begin
							(*	Printf.printf "variable de type ???\n";*)
								match getBaseType (List.assoc s !listAssocIdType)    with
									INT_TYPE ->   true
									| _  -> (*Printf.printf "variable de type autre\n";*) false
							end			
							else begin (*Printf.printf "variable %s de type non trouvee\n" s; *) false end
						end 
	|  	Sum (f, g) |Shl (f, g) | Shr (f, g) | Diff (f, g)| Prod (f, g)| Mod (f, g)| Quot (f, g) | Puis (f, g)| Maximum (f, g)
	| Minimum (f, g)  	
			-> 	(estInt) f && (estInt g)
	| 	PartieEntiereSup (e) | 	PartieEntiereInf (e)| 	Log (e)| 	Eq1 (e)	-> estInt e
   	| _	-> false


let rec estFloat exp =
	match exp with 
	 ConstInt (_)-> false
	| ConstFloat (f) -> if (floor (float_of_string f)) = (float_of_string f)  then false else true 
	| RConstFloat (f) -> if (floor ( f)) = (  f)  then false else true 
	|  	Var (s) 	-> 	if s = "EPSILON" || s = "EPSILONINT"  then true (*MARQUE*)
						else 
						begin 
							if (List.mem_assoc s !listAssocIdType)= true then 
								match getBaseType (List.assoc s !listAssocIdType)    with
									INT_TYPE ->   true
									| _  -> (*Printf.printf "variable de type autre\n"; *) false			
												
							else begin (*Printf.printf "variable de type non trouve\n";*) false end
						end 
	|  	Sum (f, g) |Shl (f, g) | Shr (f, g) | Diff (f, g)| Prod (f, g)| Mod (f, g)| Quot (f, g) | Puis (f, g)| Maximum (f, g)| 
		Minimum (f, g)  	
			-> 	(estFloat) f || (estFloat g)
	| 	PartieEntiereSup (e) | 	PartieEntiereInf (e)| 	Log (e)| 	Eq1 (e)	-> estFloat e
   	| _	-> false	
	
let estDefExp exp = match exp with ConstInt (i) | ConstFloat (i) ->  true 
 | RConstFloat (i) ->  true| _->false
let estBool exp = match exp with Boolean (_) ->true| _->false
let estBoolOrVal exp = estDefExp exp || estBool exp 


let getDefValue exp =
 match exp with 
	ConstInt(i) 			-> float_of_int (int_of_string i)
	| 	ConstFloat (f) 		->  float_of_string f
	| 	RConstFloat (f) 		->  f
	|_-> 0.0
	



let rec evalexpression  exp =
(*Printf.printf"evalexpression\n";print_expTerm exp; new_line ();*)
   match exp with
	NOCOMP -> NOCOMP	
	|  ConstInt (_) |  ConstFloat (_)  ->  exp
	|  RConstFloat (_) ->  exp
	|  Var (_)| Boolean(_) 	-> exp
	|  Sum (f, g)  -> 
		let val1 = evalexpression f in
		let val2 = evalexpression g in
		if  estNoComp val1  || estNoComp val2  then NOCOMP 
		else 
		begin 
			match val1 with
			ConstInt (i) ->
				(	let valeur = (int_of_string  i) in
					match val2 with 
					ConstInt(j) -> 		ConstInt(Printf.sprintf "%d" (valeur + (int_of_string  j)))
					|ConstFloat(j)-> 	RConstFloat (  ((float_of_string  i) +. (float_of_string  j)))
					|RConstFloat(j)-> 	RConstFloat ( ((float_of_string  i) +. (  j)))
					|Var(v) -> 			Sum(Var(v),val1)
					|_->exp
				)				
			|ConstFloat (i)->	
			(
				let valeur1 = (float_of_string  i) in
				match val2 with 
					ConstInt(j) -> 		RConstFloat(  (valeur1 +. (float_of_string  j)))
					|ConstFloat (j)-> 	RConstFloat(  (valeur1 +. (float_of_string  j)))
					|RConstFloat (j)-> 	RConstFloat(  (valeur1 +. (  j)))
					|Var(v) -> (*	if valeur1 = 0.0 then val2 else  begin (*Printf.printf "somme val2, val1\n";*)*) Sum(Var(v),val1) (*end*)
					|_->exp
			)
			|RConstFloat (i)->	
			(
				let valeur1 = (  i) in
				match val2 with 
					ConstInt(j) -> 		RConstFloat( (valeur1 +. (float_of_string  j)))
					|ConstFloat (j)-> 	RConstFloat( (valeur1 +. (float_of_string  j)))
					|RConstFloat (j)-> 	RConstFloat(  (valeur1 +. (   j)))
					|Var(v) -> (*	if valeur1 = 0.0 then val2 else  begin (*Printf.printf "somme val2, val1\n";*) *) Sum(Var(v),val1) (*end*)
					|_->exp
			)
			|Var(_) -> 
			(
				match val2 with 
					ConstInt(j) -> 			Sum(val2,val1)
					|ConstFloat (j)->		(*if (float_of_string  j) = 0.0 then val1 else *)Sum(val2,val1)
					|RConstFloat (j)->		(*if (  j) = 0.0 then val1 else*) Sum(val2,val1)
					|Var(_) ->  			Sum(val2,val1)
					|_->exp
			)
			| _ ->exp
		end
  	| Diff (f, g)   -> 
		let val1 = evalexpression f in
		let val2 = evalexpression g in
		if estNoComp val1 || estNoComp val2 then NOCOMP 
		else 
			begin 
				match val1 with
				ConstInt (i) ->
					begin
						match val2 with 
						ConstInt(j) -> 	  ConstInt(Printf.sprintf "%d"  ((int_of_string  i) - (int_of_string  j)))
						|ConstFloat (j)-> RConstFloat( ((float_of_string  i) -. (float_of_string  j)))
						|RConstFloat (j)-> RConstFloat(  ((float_of_string  i) -. (  j)))
						|Var(v) -> 		  Diff(val1,val2)
						|_->exp
					end				
				|ConstFloat (i)->	
					begin
						let valeur1 = (float_of_string  i) in
						match val2 with 
						ConstInt(j) -> 		RConstFloat( (valeur1 -. (float_of_string  j)))
						|ConstFloat (j)-> 	RConstFloat(  (valeur1 -. (float_of_string  j)))
						|RConstFloat (j)-> 	RConstFloat(  (valeur1 -. (   j)))
						|Var(v) -> 			 Diff(val1,val2)
						|_->exp
					end
				|RConstFloat (i)->	
					begin
						let valeur1 = (  i) in
						match val2 with 
						ConstInt(j) -> 		RConstFloat(  (valeur1 -. (float_of_string  j)))
						|ConstFloat (j)-> 	RConstFloat(  (valeur1 -. (float_of_string  j)))
						|RConstFloat (j)-> 	RConstFloat(  (valeur1 -. (   j)))
						|Var(v) -> 			   Diff(val1,val2)
						|_->exp
					end
				|Var(v) -> 
				(
					match val2 with 
					ConstInt(j) -> 			Diff(val1,val2)
					|ConstFloat (j)-> 		(*if (float_of_string  j) = 0.0 then 	val1	else*) Diff(val1,val2)
					|RConstFloat (j)-> 		(*if ( j) = 0.0 then 	val1	else *) Diff(val1,val2)
					|Var(v) ->  Diff(val1,val2)
					|_->exp	
				)
				|_->exp
		end
	| 	Puis (f, g)    	->

(*Printf.printf "evalexpression pow\n";*)
		let val1 = evalexpression f in
		let val2 = evalexpression g in
(* print_expTerm	val1;
 print_expTerm	val2;new_line();*)

		if estNoComp val1  || estNoComp val2  then NOCOMP 
		else 
		begin 
			match val1 with
			ConstInt (i) ->
				if (int_of_string  i) = 1 then ConstInt("1")
				else			
					(match val2 with 
					ConstInt(j) |ConstFloat (j)-> 
						let val2 = (float_of_string  j) in
						if val2  = 1.0 then	ConstInt (i) else RConstFloat(  ((float_of_string  i) **val2))
					|RConstFloat (j)-> 
						let val2 = (  j) in
						if val2  = 1.0 then	ConstInt (i) else RConstFloat(  ((float_of_string  i) **val2))
					|Var(v) ->   Puis (val1,val2)
					|_->exp)
									
			|ConstFloat (i)->	
				begin
					let valeur1 = (float_of_string  i) in
					if valeur1 = 1.0 then ConstInt("1")
					else
					(match val2 with 
						ConstInt(j) ->
							let val2 = (float_of_string  j) in
							if val2  = 1.0 then	RConstFloat (valeur1)
							else RConstFloat(  (valeur1 ** (float_of_string  j)))
						|RConstFloat (j) -> 
							let val2 = (  j) in
							if val2  = 1.0 then	RConstFloat (valeur1)  else RConstFloat( (valeur1 ** (  j)))
						|ConstFloat (j) -> 
							let val2 = (float_of_string  j) in
							if val2  = 1.0 then	RConstFloat (valeur1)  else RConstFloat(  (valeur1 ** (float_of_string  j)))
						|Var(v) ->   Puis(val1,val2)
						|_->exp)
				end
			|RConstFloat (i)->	
				begin
					let valeur1 = ( i) in
					if valeur1 = 1.0 then ConstInt("1")
					else
					(match val2 with 
						ConstInt(j) ->
							let val2 = (float_of_string  j) in
							if val2  = 1.0 then	RConstFloat (i)
							else RConstFloat(  (valeur1 ** (float_of_string  j)))
						|ConstFloat (j) -> 
							let val2 = (float_of_string  j) in
							if val2  = 1.0 then	RConstFloat (i)  else RConstFloat( (valeur1 ** (float_of_string  j)))
						|RConstFloat (j) -> 
							let val2 = (  j) in
							if val2  = 1.0 then	RConstFloat (i)  else RConstFloat(  (valeur1 ** ( j)))
						|Var(v) ->   Puis(val1,val2)
						|_->exp)
				end
			|Var(v) -> 
				begin
					match val2 with 
					ConstInt(j) -> 
						if (float_of_string  j) = 0.0 then ConstInt("1")
						else if (float_of_string  j) = 1.0 then	val1 else Puis(val1,val2)
					|ConstFloat (j)-> 		
						if (float_of_string  j) = 0.0 then ConstInt("1")
						else if (float_of_string  j) = 1.0 then	val1 else Puis(val1,val2)
					|RConstFloat (j)-> 		
						if ( j) = 0.0 then ConstInt("1")
						else if (  j) = 1.0 then	val1 else Puis(val1,val2)
					|Var(v) ->  Puis(val1,val2)
					|_->exp
				end						
			|_->exp
		end
	| Prod (f, g)  	->
		let val1 = evalexpression f in
		let val2 = evalexpression g in

		if estNoComp val1  || estNoComp val2  then NOCOMP 
		else 
		begin 
			match val1 with
			ConstInt (i) ->
				begin
					match val2 with 
					ConstInt(j) -> 
						ConstInt(Printf.sprintf "%d"  ((int_of_string  i) * (int_of_string  j)))
					|ConstFloat (j)-> 
					 RConstFloat( ((float_of_string  i)*. (float_of_string  j)))
					|RConstFloat (j)-> 
					 RConstFloat(  ((float_of_string  i)*. ( j)))
					|Var(v) -> if (int_of_string  i) = 0 then ConstInt("0")
							  else if (int_of_string  i) = 1  then	 val2 else  Prod (val2,val1)
					|_->exp
				end				
		  	|ConstFloat (i)->	
				begin
					let valeur1 = (float_of_string  i) in
					match val2 with 
					ConstInt(j) -> 
						RConstFloat(  (valeur1 *. (float_of_string  j)))
					|ConstFloat (j)-> 		
						RConstFloat(  (valeur1 *. (float_of_string  j)))
					|RConstFloat (j)-> 		
						RConstFloat( (valeur1 *. ( j)))
					|Var(v) -> if valeur1 = 0.0 then ConstInt("0")
							  else if valeur1 = 1.0  then	 val2 else  Prod(val1,val2)
					|_->exp
				end
		  	|RConstFloat (i)->	
				begin
					let valeur1 = (  i) in
					match val2 with 
					ConstInt(j) -> 
						RConstFloat(  (valeur1 *. (float_of_string  j)))
					|ConstFloat (j)-> 		
						RConstFloat( (valeur1 *. (float_of_string  j)))
					|RConstFloat (j)-> 		
						RConstFloat(  (valeur1 *. ( j)))
					|Var(v) -> if valeur1 = 0.0 then ConstInt("0")
							  else if valeur1 = 1.0  then	 val2 else  Prod(val1,val2)
					|_->exp
				end
			|Var(v) -> 
				begin
					match val2 with 
					ConstInt(j) -> 
						if (float_of_string  j) = 0.0 then ConstInt("0")
						else if (float_of_string  j) = 1.0 then	val1 else Prod(val2,val1)
					|ConstFloat (j)-> 		
						if (float_of_string  j) = 0.0 then ConstInt("0")
						else if (float_of_string  j) = 1.0 then	val1 else Prod(val2,val1)
					|RConstFloat (j)-> 		
						if (  j) = 0.0 then ConstInt("0")
						else if (   j) = 1.0 then	val1 else Prod(val2,val1)
					|Var(v) ->  Prod(val2,val1)
					|_->exp
				end					
			|_->exp
		end
	| Shr (f, g)  	->
		let val1 = evalexpression f in
		let val2 = evalexpression g in

		if estNoComp val1  || estNoComp val2  then NOCOMP 
		else 
		begin 
			match val1 with
			ConstInt (i) ->
				begin
					let nbdec = (int_of_string  i) in 
					match val2 with 
					ConstInt(j) ->  ConstInt(Printf.sprintf "%d"  (nbdec lsr (int_of_string  j)))
					|ConstFloat (j)->  ConstInt(Printf.sprintf "%d" (nbdec lsr (int_of_string  j)))
					(*|RConstFloat (j)->  
							ConstInt(Printf.sprintf "%d" (nbdec lsr (int_of_string  j)))*)
					|Var(v) ->  if nbdec = 0 then ConstInt("0") else Quot (val1,Puis (ConstInt("2"), Var(v)) )
					|_->exp
				end				
			|ConstFloat (i)->	
				begin
					let valeur1 = (int_of_string   i) in
					match val2 with 
					ConstInt(j) ->  ConstInt(Printf.sprintf "%d" (valeur1 lsr (int_of_string  j)))
					|ConstFloat (j)->ConstInt(Printf.sprintf "%d" (valeur1 lsr (int_of_string  j)))
					|Var(v) -> if valeur1 = 0 then ConstInt("0")  else  Quot (val1,Puis (ConstInt("2"), Var(v)) )
					|_->exp
				end
			|RConstFloat (i)->	
				begin
					let valeur1 = (   i) in
					match val2 with 
					(*ConstInt(j) ->  ConstInt(Printf.sprintf "%d" (valeur1 lsr (int_of_string  j)))
					|ConstFloat (j)->ConstInt(Printf.sprintf "%d" (valeur1 lsr (int_of_string  j)))*)
					|Var(v) -> if valeur1 = 0.0 then ConstInt("0")  else  Quot (val1,Puis (ConstInt("2"), Var(v)) )
					|_->exp
				end
			|Var(v) -> 
				begin
					match val2 with 
					ConstInt(j) -> let nbdec = (int_of_string  j) in  if nbdec = 0 then val1 else Shr(val1,val2)
					|ConstFloat (j)-> let nbdec = (int_of_string  j) in  if nbdec = 0 then val1 else  Shr(val1,val2)
					|RConstFloat (j)-> let nbdec = (  j) in  if nbdec = 0.0 then val1 else  Shr(val1,val2)
					|Var(v) -> Quot (val1,Puis (ConstInt("2"), Var(v)) )
					|_->exp
				end					
			|_->exp
		end
	| Shl (f, g)  	->
		let val1 = evalexpression f in
		let val2 = evalexpression g in

		if estNoComp val1  || estNoComp val2  then NOCOMP 
		else 
			begin 
				match val1 with
				ConstInt (i) ->
					begin
						match val2 with 
						ConstInt(j) ->      ConstInt(Printf.sprintf "%d"  ((int_of_string  i) lsl (int_of_string  j)))
						|ConstFloat (j)->   ConstInt(Printf.sprintf "%d" ((int_of_string   i) lsl (int_of_string  j)))
						|Var(v) -> if (int_of_string  i) = 0 then ConstInt("0") else Prod (val1,Puis (ConstInt("2"), Var(v)) )
						|_->exp
					end				
				|ConstFloat (i)->	
					begin
						let valeur1 = (int_of_string   i) in
						match val2 with 
						ConstInt(j) ->  ConstInt(Printf.sprintf "%d" (valeur1 lsl (int_of_string  j)))
						|ConstFloat (j)->  ConstInt(Printf.sprintf "%d" (valeur1 lsl (int_of_string  j)))
						|Var(v) -> if valeur1 = 0 then ConstInt("0") else  Prod (val1,Puis (ConstInt("2"), Var(v)) )
						|_->exp
					end
				|Var(v) -> 
					begin
						match val2 with 
						ConstInt(j) -> 		let nbdec = (int_of_string  j) in  if nbdec = 0 then val1 else Prod (val1,Puis (ConstInt("2"), Var(v)) )
						|ConstFloat (j)-> 	let nbdec = (int_of_string  j) in if nbdec = 0 then val1 else Prod (val1,Puis (ConstInt("2"), Var(v)) )
						|RConstFloat (j)-> 	let nbdec = (  j) in if nbdec = 0.0 then val1 else Prod (val1,Puis (ConstInt("2"), Var(v)) )
						|Var(v) ->  Prod (val1,Puis (ConstInt("2"), Var(v)) )
						|_->exp
					end				
				|_->exp
		end
	| Mod (f, g)  	-> 
		let val1 = evalexpression f in
		let val2 = evalexpression g in
		if estNoComp val1  || estNoComp val2  then NOCOMP 
		else 
			begin 
				match val1 with
				ConstInt (i) ->
					begin
						match val2 with 
						ConstInt(j) -> 
						 ConstInt(Printf.sprintf "%d"  ((int_of_string  i) mod (int_of_string  j)))
						|Var(v) ->  Mod(val1,val2)
						|_->exp				
					end
				|Var(v) ->
					(
						match val2 with 
						ConstInt(j) -> if (float_of_string  j) = 1.0 then val1 else Mod(val1,val2)
						|ConstFloat(j)->if (float_of_string  j) = 1.0 then val1 else Mod(val1,val2)
						|RConstFloat(j)->if (  j) = 1.0 then val1 else Mod(val1,val2)
						|Var(v1) ->  if v = v1 then ConstInt("0") else  Mod(val1,val2)
						|_->exp
					)				  
				|_->exp
			end
	| Quot (f, g)  -> 
		let val1 = evalexpression f in
		let val2 = evalexpression g in
		if estNoComp val1  || estNoComp val2 || estNul val2 then NOCOMP 
		else 
			begin 
				match val1 with
				ConstInt (i) ->
					begin
						match val2 with 
						ConstInt(j) ->  ConstInt(Printf.sprintf "%d" ((int_of_string  i) / (int_of_string  j)))
						|ConstFloat (j)->   RConstFloat( ((float_of_string  i)/. (float_of_string  j)))
						|RConstFloat (j)->   RConstFloat( ((float_of_string  i)/. ( j)))
						|Var(v) ->  Quot(val1,val2)
						|_->exp
					end				
			  	|ConstFloat (i)->	
					begin
						let valeur1 = (float_of_string  i) in
						match val2 with 
						ConstInt(j) ->  RConstFloat( (valeur1 /. (float_of_string  j)))
						|ConstFloat (j)-> RConstFloat(  (valeur1 /. (float_of_string  j)))
						|RConstFloat (j)-> RConstFloat(  (valeur1 /. ( j)))
						|Var(v) ->  Quot(val1,val2)
						|_->exp
					end
				|RConstFloat (i)->	
					begin
						let valeur1 = (   i) in
						match val2 with 
						ConstInt(j) ->  RConstFloat( (valeur1 /. (float_of_string  j)))
						|ConstFloat (j)-> RConstFloat(  (valeur1 /. (float_of_string  j)))
						|RConstFloat (j)-> RConstFloat(  (valeur1 /. ( j)))
						|Var(v) ->  Quot(val1,val2)
						|_->exp
					end
				|Var(v) ->
					(
						match val2 with 
						ConstInt(j) ->     if (float_of_string  j) = 1.0 then	val1	else Quot(val1,val2)
						|ConstFloat (j)->  if (float_of_string  j) = 1.0 then	val1	else Quot(val1,val2)
						|RConstFloat (j)->  if ( j) = 1.0 then	val1	else Quot(val1,val2)
						|Var(v1) ->  
							if v = v1 then (  ConstInt("1"))
							else  (   Quot(val1,val2))
						|_->exp
					)
				| Prod (e1, e2)  	-> 
							let ne1 = evalexpression( Quot(e1,val2)) in
							let ne2 = evalexpression( Quot(e2,val2)) in
							(match ne1 with 
								ConstInt(j) -> Prod (ne1, e2)
								|_->
										(match ne2 with
												ConstInt(j)  ->Prod (e1, ne2)
												|_-> exp)
							)
				|_->exp
		end
   | PartieEntiereSup (e)-> 
		let val1 = evalexpression e in 	
		if estNoComp val1  then NOCOMP
		else
			begin
				match val1 with
				ConstInt(_) 	-> val1
				| 	ConstFloat (f) ->	let valeur = (float_of_string f) in
										let pe = truncate valeur in
										let (_,partieFract) =modf valeur in
										if partieFract  = 0.0 then ConstInt(Printf.sprintf "%d" pe)
										else 	ConstInt(Printf.sprintf "%d" (pe + 1)) (*is_integer_num*)
				| 	RConstFloat (f) ->	let valeur = ( f) in
										let pe = truncate valeur in
										let (_,partieFract) =modf valeur in
										if partieFract  = 0.0 then ConstInt(Printf.sprintf "%d" pe)
										else 	ConstInt(Printf.sprintf "%d" (pe + 1)) (*is_integer_num*)
				|_				-> 	exp
			end
   | PartieEntiereInf (e)-> 
		let val1 = evalexpression e in 
		if estNoComp val1  then 
		begin
			NOCOMP
		end  
		else 
		begin
			match val1 with
			ConstInt(_) 	-> val1
			| 	ConstFloat (f) 	->	
						(*Printf.printf "%d %f %s\n"(truncate ( float_of_string f)) (float_of_string f) f;*)
				 
				let vf = (float_of_string f) in
				if float (truncate vf) <= vf then
						ConstInt(Printf.sprintf "%d" (truncate vf))
						else if vf>=1.0 then ConstInt(Printf.sprintf "%d" (truncate (vf) - 1)) else ConstInt("0")

			| 	RConstFloat (f) 	->	
							(*Printf.printf "%d %f %e r\n"(truncate ( f)) f f;*)
						if float (truncate ( f)) <= f then
						ConstInt(Printf.sprintf "%d" (truncate ( f)))
						else if f>=1.0 then ConstInt(Printf.sprintf "%d" (truncate ( f) - 1)) else ConstInt("0")
			|	Var(v)			-> 	PartieEntiereInf (e)
			|	_				->	exp
		end
   | Sygma (var,min,max,e)-> 	exp
   | Log (e)-> 	let val1 = evalexpression e in 
		if estNoComp val1  then NOCOMP 
		else 
		begin
			match val1 with
			ConstInt(v) 	-> if val1 = ConstInt("0") then  NOCOMP else RConstFloat (  (log ( float_of_string v)))
			| 	ConstFloat (f) 	->	if val1 = ConstFloat("0.O") then  NOCOMP else  RConstFloat (  (log ( float_of_string f)))
			| 	RConstFloat (f) 	->	if val1 = RConstFloat(0.0) then  NOCOMP else  RConstFloat (  (log ( f)))
			|	Var(v)			-> 	Log (val1)
			|	_				->	Log (val1)
			end	
   | Max (var,min,max,e)-> 	exp
   | Eq1 (e1)-> 			
		let val1 = evalexpression e1 in 
		if estNoComp val1  then NOCOMP 
		else 
		begin
			match val1 with
			ConstInt(_) 	->      if val1 = ConstInt("1") then ConstInt("1") else ConstInt("0")
			| 	ConstFloat (f) 	->if val1 = ConstFloat("1.0") then ConstInt("1") else ConstInt("0")
			| 	RConstFloat (f) 	->if val1 = RConstFloat(1.0) then ConstInt("1") else ConstInt("0")
			|	Var(v)			-> 	Eq1 (val1)
			|	_				->	exp
		end
	|  Maximum (f, g)  			-> 	
		let val1 = evalexpression f in
		let val2 = evalexpression g in
		if estNoComp val1 || estNoComp val2 then NOCOMP 
		else  if estDefExp val1  &&  estDefExp val2 then maxi val1 val2
			 else NOCOMP
	
	|  Minimum (f, g)  	-> 	
		let val1 = evalexpression f in
		let val2 = evalexpression g in
		if estNoComp val1  &&  estNoComp val2 then NOCOMP
		else if estDefExp val1  &&  estDefExp val2 then mini val1 val2
			 else((*Printf.printf "minimum"*) (*if  estDefExp val1 then val1 else val2*)NOCOMP)
and mini v1 v2 = if estDefExp v1 && estDefExp v2 then if estPositif (evalexpression (Diff( v1, v2))) then v2 else v1 else NOCOMP
and maxi v1 v2 = if estDefExp v1 && estDefExp v2 then if estPositif (evalexpression (Diff( v1, v2))) then v1 else v2 else NOCOMP
		

let rec  prodListSize l =
if l = [] then ConstInt ("1")
else  evalexpression(	Prod (ConstInt (Printf.sprintf "%d" (List.hd l)), prodListSize (List.tl l) ))



let rec  prodListSizeIndex l l2=
if l = [] then  CONSTANT(CONST_INT("1"))
else  
begin
	if l2 = [] then CONSTANT(CONST_INT("0"))
	else
	begin
		let (firstSize, nextSize) =  (List.hd l, List.tl l) in
		let (firstIndex, nextIndex) =  (List.hd l2, List.tl l2) in
		BINARY(ADD,BINARY (MUL,firstIndex, expressionEvalueeToExpression (prodListSize nextSize)), prodListSizeIndex nextSize nextIndex)
		
	end
end


let rec reecrireSygma var expO =
	match expO with
		 BINARY (op, exp1, exp2) ->BINARY (op, reecrireSygma var  exp1, reecrireSygma var  exp2) 
		| CALL (exp, args) ->	
			begin
				match exp with		
					VARIABLE("SYGMA") -> Printf.printf "reecrireSygma :"	;	
						(*print_expression expO 0; new_line();*)
						let varexp = List.hd args in
					 	let suite = List.tl args in
						(match varexp with	
							VARIABLE (varS) ->	
								let max = List.hd suite in
								let expE =List.hd (List.tl suite)  in
								if varS = var then
								begin			
									(*Printf.printf "reecrireSygma :remplacer  varS = var %s\n"	var;	*)
									BINARY(MUL, BINARY(ADD,max,(CONSTANT (CONST_INT "1"))) , expE)
								end
								else
								begin
								(*Printf.printf "reecrireSygma : sygma varS %s!= var%s\n"varS var	;*)
									let newmax = reecrireSygma var max in
									let newexp =  reecrireSygma var expE in
									let newargs = List.append [VARIABLE (varS)] (List.append [newmax][newexp]) in
									CALL (exp, newargs)
								end 	
							|_-> expO);				
					|_-> 
						begin
							let newargs = List.map (fun arg->reecrireSygma var  arg)args in
							CALL (exp, newargs)
						end 
			end	
		| _ -> 	expO

let rec listVARMAXSYG var expO =
	match expO with
		 BINARY (_, exp1, exp2) ->  (listVARMAXSYG  var exp1) || (listVARMAXSYG var exp2) 
		| UNARY (_, exp1) ->  (listVARMAXSYG  var exp1) 
		| CALL (exp, args) ->	
			(
				match exp with		
					VARIABLE("SYGMA")|VARIABLE("MAX") -> 
						 
						let varexp = List.hd args in
					 	let suite = List.tl args in 
						(match varexp with	
							VARIABLE (varS) ->	if varS = var then true 
								else listVARMAXSYG var  (List.hd suite)  || listVARMAXSYG var (List.hd (List.tl suite))
							|_-> false);				
					|_-> listVARMAXSYGOfArgs var args  
			)	
		| _ -> 	false

and listVARMAXSYGOfArgs var l =
if l = [] then false else  
begin
	 (listVARMAXSYG var (List.hd l)) || (listVARMAXSYGOfArgs var ( List.tl l)) 
end





	
let rec remplacerValPar0  var expr =

	match expr with
	NOTHING 					-> NOTHING
	| UNARY (op, exp) 			-> UNARY (op, remplacerValPar0   var exp)
	| BINARY (op, exp1, exp2) 	-> BINARY (op, remplacerValPar0   var  exp1, remplacerValPar0   var exp2)
	| CALL (exp, args) 			->	CALL (exp, List.map(fun a-> remplacerValPar0  var a)args)
	| VARIABLE (s) 				->	if s = var then CONSTANT (CONST_INT "0") else expr
	| INDEX (n,exp) 			->	INDEX (n, remplacerValPar0   var exp); 
	| CONSTANT ( CONST_COMPOUND expsc)  -> CONSTANT ( CONST_COMPOUND ( List.map(fun a-> remplacerValPar0  var  a)expsc))
	| COMMA exps 					->	(COMMA ( List.map (fun a -> remplacerValPar0  var  a) exps))
	| _ 						-> 	expr

(*		| MEMOF -> ("*", 13)
		| ADDROF -> ("&", 13)*)

let rec mapVar fct = function 
         NOTHING				-> NOTHING
	|UNARY (op, exp)			-> UNARY (op, mapVar fct exp)
	| BINARY (op, exp1, exp2) 		-> BINARY (op, mapVar fct exp1, mapVar fct exp2)
	| CALL (exp, args) 			->	CALL (exp, List.map(fun a-> mapVar fct a)args)
	| VARIABLE (s) 				->	VARIABLE (fct s)
	| INDEX (n,exp) 			->	INDEX (n, mapVar fct exp)
	| CONSTANT ( CONST_COMPOUND expsc)  -> CONSTANT ( CONST_COMPOUND ( List.map(fun a-> mapVar fct a)expsc))
	| COMMA exps 					->	(COMMA ( List.map (fun a -> mapVar fct a) exps))
	| expr 					-> 	expr
	
let rec remplacerNOTHINGPar  expr =
	match expr with
	NOTHING 					-> VARIABLE ("NODEF") 
	| UNARY (op, exp) 			-> UNARY (op, remplacerNOTHINGPar    exp)
	| BINARY (op, exp1, exp2) 	-> BINARY (op, remplacerNOTHINGPar exp1, remplacerNOTHINGPar exp2)
	| CALL (exp, args) 			->	CALL (exp, List.map(fun a-> remplacerNOTHINGPar a)args)
	| VARIABLE (s) 				->	expr
	| INDEX (n,exp) 			->	INDEX (n, remplacerNOTHINGPar    exp)

	| _ 						-> 	expr



let rec remplacergetvarTailleTabMaxFctPar  expr ne =
	match expr with
	NOTHING 					-> NOTHING
	| UNARY (op, exp) 			-> UNARY (op, remplacergetvarTailleTabMaxFctPar    exp ne)
	| BINARY (op, exp1, exp2) 	-> BINARY (op, remplacergetvarTailleTabMaxFctPar exp1 ne, remplacergetvarTailleTabMaxFctPar exp2 ne)
	| CALL(VARIABLE("getvarTailleTabMax_"), _)-> ne
	| CALL (exp, args) 			->	CALL (exp, List.map(fun a-> remplacergetvarTailleTabMaxFctPar a ne )args)
	| _ 						-> 	expr



let rec isNoDef  expr =
	match expr with
	NOTHING 					-> true
	| UNARY (op, exp) 			-> isNoDef   exp
	| BINARY (op, exp1, exp2) 	-> isNoDef exp1 || isNoDef exp2
	| CALL (exp, args) 			->	isNoDef exp ||  traiterCOMMADEF args
	| VARIABLE (s) 				->	false
	| INDEX (n,exp) 			->	isNoDef n || isNoDef    exp
	| _ 						-> 	false

and traiterCOMMADEF args =
if args = [] then false
else isNoDef (List.hd  args) || traiterCOMMADEF (List.tl  args)

let rec mapAffect fct = function
  (VAR(ident, expr)) -> (VAR((fct ident), expr))
  | autre -> autre 

let mapListAffect fct = List.map (mapAffect fct)


let remplacerNOTHINGParAux e =
match e with MULTIPLE ->VARIABLE ("NODEF") | EXP (e) -> if e = NOTHING then VARIABLE ("NODEF")  else remplacerNOTHINGPar e 

let signOf op =
	match op with
				ADD		->  1	
				| SUB		->  -1	
				| MUL	   	->  1
				| DIV		-> -1
				| MOD		-> -1
				| SHL 		->  1
				| SHR		-> -1		
				| _ 		->  0


let afficherAS a =
match a with
		ASSIGN_SIMPLE (s, e) 	 -> 
		(match e with EXP(ex) ->print_expression  (BINARY(ASSIGN, VARIABLE(s),  ex)) 0
						|_->print_expression  (BINARY(ASSIGN,VARIABLE(s), VARIABLE("NODEF"))) 0)
	|	ASSIGN_DOUBLE (s,e1, e2) -> 
		
			(match e1 with EXP(e) ->  
						(match e2 with EXP(ex) ->print_expression  (BINARY(ASSIGN,INDEX(VARIABLE(s),  e),  ex)) 0
						 	|_->print_expression  (BINARY(ASSIGN,INDEX(VARIABLE(s),  e),  VARIABLE("?"))) 0)
					| _->print_expression  (BINARY(ASSIGN,INDEX(VARIABLE(s),  VARIABLE("NODEF")),  VARIABLE("NODEF"))) 0)
				 
	|   ASSIGN_MEM (s, e1, e2)	-> 		(*Printf.printf "mem assign affich\n";*)
			(match e1 with EXP(e) ->  
						(match e2 with EXP(ex) ->print_expression  (BINARY(ASSIGN,INDEX(VARIABLE(s),  e),  ex)) 0
						 	|_->print_expression  (BINARY(ASSIGN,INDEX(VARIABLE(s),  e),  VARIABLE("NODEF"))) 0)
					| _->print_expression  (BINARY(ASSIGN,INDEX(VARIABLE(s),  VARIABLE("NODEF")),  VARIABLE("NODEF"))) 0)

let afficherListeAS asL =space(); new_line() ;flush(); List.iter (fun a-> afficherAS a; space(); new_line() ;flush(); )asL
let  expVaToExp exp = match exp with EXP(e) ->e| _->NOTHING
let hasSETCALL  =ref true



let rec simplifierValeur exp =
 match exp with
		UNARY (MEMOF, exp1)->
			 (match exp1 with UNARY (ADDROF, next) ->  simplifierValeur  next |_->exp	 )
						 
		|UNARY (ADDROF, exp1)->    	
			(match exp1 with  UNARY (MEMOF, next) ->   simplifierValeur  next |_->exp)
		|_-> exp
	
 

let rec consArrayFromPtrExp exp arrayName =


	let valsi = simplifierValeur exp in 

	 match valsi with
		
		 UNARY (op, exp)	-> 
			(match op with
				MINUS | PLUS-> let varOfExp = (listeDesVarsDeExpSeules exp) in
							   if List.mem arrayName varOfExp = false then (exp, false)
							   else (NOTHING, false)
				|_->(NOTHING, false) )

		| BINARY (op, exp1, exp2) ->
			
			let varOfExp1 = (listeDesVarsDeExpSeules exp1) in
			let varOfExp2 = (listeDesVarsDeExpSeules exp2) in
			if List.mem arrayName varOfExp1 = false then
			begin
				let (resexp2, hasArray) = consArrayFromPtrExp exp2 arrayName in
				if hasArray then
					match op with
					 ADD|SUB -> if resexp2 = NOTHING then ( exp1, true) else ( BINARY(op, exp1, resexp2), true)
						|_-> (NOTHING, false)
				else (NOTHING, false)
			end
			else 
			begin
				
				if List.mem arrayName varOfExp2 = false then
				begin
					let (resexp1, hasArray) = consArrayFromPtrExp exp1 arrayName in
					if hasArray then
						match op with
						 ADD|SUB -> if resexp1 = NOTHING then (exp2, true) else ( BINARY(op, resexp1, exp2), true)
							|_-> (NOTHING, false)
					else (NOTHING, false)
	
				end
				else (NOTHING,false)
			end
		| CONSTANT c-> (exp,false)
		| VARIABLE name ->  if name = arrayName then (NOTHING, true) 
							else if (String.length name > 4) then
									if (String.sub name  0 4) = "bIt-" then  (exp, false) else (NOTHING, false)
								 else (NOTHING, false)		(* sinon pb si ptr=tab+k ; k=k+1; *ptr=... donc pour le moment que constante*)						
		| INDEX (_,_)-> 
			(*Printf.printf"actuellement  non traitée index\n";*)(* actuellement  non traitée *)

			let (tab,lidx) = analyseArray valsi []  in
			if (List.mem_assoc tab !listAssosArrayIDsize) then
			begin
				let size = getAssosArrayIDsize tab in
				let (res,isok) = 
					(match size with 
						NOSIZE -> (NOTHING, false)
						| SARRAY (v) -> Printf.printf"cas 1 index\n";
							
						consArrayFromPtrExp (BINARY (ADD,  VARIABLE(tab),List.hd lidx)) arrayName
	 
								 
						| MSARRAY (lsize) -> let index = prodListSizeIndex lsize lidx in  
											 	consArrayFromPtrExp (BINARY (ADD,  VARIABLE(tab),index)) arrayName ) in(* (NOTHING, false)in*)
					(*print_expression VARIABLE(tab)) 0;  print_expression res 0; 
					if isok then Printf.printf "OK\n";*)
					(*(res, isok)*)(res, isok)
					
			end else (NOTHING, false)

			 
		|_ ->(*Printf.printf"actuellement  non traitée\n";*)(* actuellement  non traitée *)(NOTHING, false)



and getArrayAssign  x index assign =
		(*	Printf.printf "variable *%s " ptr_name; afficherAS ro2x; flush(); new_line(); *)
		(*Printf.printf "variable %s " x ;
		Printf.printf "<- \n" ;	print_expression (expVaToExp assign)  0; new_line(); flush() ;space(); flush(); new_line(); flush();*)
		let (tab1,_, _) =getArrayNameOfexp (expVaToExp index) in
								
		if tab1 != "" then
		begin
		(*	Printf.printf "tableau tab trouve tab %s ptr %s \n" tab1 x;*)
			
			let (indexexp , isok) = consArrayFromPtrExp (expVaToExp index )  tab1 in
			if isok then 
			begin
				(*let resindex = expressionEvalueeToExpression( calculer (EXP(indexexp))  !infoaffichNull [] 1) in*)
				(*print_expression  (INDEX(VARIABLE(tab1), resindex)) 0; new_line(); flush() ;space(); flush(); new_line(); flush();
				Printf.printf "<- \n" ;print_expression (expVaToExp assign) 0; new_line(); flush() ;space flush; new_line(); flush();*)
			 
				(new_assign_double tab1 (EXP(indexexp)) assign,true,tab1, (EXP(indexexp)))
			end (*A*)else (new_assign_mem x index assign ,false,"", MULTIPLE)
		end 
		else
		begin
			(*Printf.printf "tableau tab trouve tab %s ptr %s \n" tab1 x;*)
			 (new_assign_mem x index assign ,false,"", MULTIPLE)
		end


and getArrayAssignFromMem  x index  = 
		let (tab1,_, _) =getArrayNameOfexp (expVaToExp index) in				
		if tab1 != "" then
		begin
		 
			let (indexexp , isok) = consArrayFromPtrExp (expVaToExp index )  tab1 in
			if indexexp != NOTHING then (tab1, (EXP(indexexp)) ,true) else (tab1, MULTIPLE , true)
		end 
		else  (x, index  ,false)



and arrayAssignFilter var liste=
List.filter (fun aSCourant -> match aSCourant with ASSIGN_SIMPLE (id, _)  |	ASSIGN_DOUBLE (id, _, _)  |ASSIGN_MEM (id, _, _)	->  (id = var)  ) liste



and  calculer expressionVA ia l sign =
	match expressionVA with
	EXP  (expr) ->
	(	match expr with
		NOTHING -> (*Printf.printf "calculer NOTHING\n";*)NOCOMP
		| EXPR_LINE (expr, _, _) -> calculer (EXP(expr)) ia l sign 
		| UNARY (op, exp) ->
			begin
				
				
					match op with
					MINUS ->  	
							let val1 = calculer (EXP exp) ia l (-1* sign) in
							if estNoComp val1   then NOCOMP else 	evalexpression(	Diff (ConstInt ("0"), val1)) (*voir*)
					| PLUS ->  	
							let val1 = calculer (EXP exp) ia l sign in 
							if estNoComp val1   then NOCOMP else	evalexpression	val1 (*voir*)
					| NOT ->
							let val1 = calculer (EXP exp) ia l 0 in   	
								if estNoComp val1   then NOCOMP
								else (* print_expTerm val1;new_line();*)
									if val1 = Boolean(true) || val1 = ConstInt ("1") 
										|| val1 = ConstFloat("1.0")|| val1 = RConstFloat(1.0)
									then Boolean(false) 
									else	if val1 = Boolean (false)||val1=ConstInt("0")||val1=ConstFloat("0.0")||val1=RConstFloat(0.0)					
											then Boolean(true) else NOCOMP (*neg*)
					| BNOT -> 	NOCOMP
					| MEMOF  -> (*Printf.printf" calculer MEMOF\n";print_expression exp 0; new_line();*)
						
						( match exp with  UNARY(ADDROF, exp2) ->   calculer (EXP exp2) ia l sign
											|_-> NOCOMP)
					| ADDROF ->   
						( match exp with  UNARY(MEMOF, exp2) ->  calculer (EXP exp2) ia l sign
										  
											|_-> NOCOMP)
					| PREINCR ->  let val1 = calculer (EXP exp) ia l sign in if estNoComp val1 then NOCOMP else evalexpression (Sum (val1, ConstInt ("1")))
					| PREDECR ->  let val1 = calculer (EXP exp) ia l sign in if estNoComp val1 then NOCOMP else evalexpression (Diff (val1, ConstInt ("1")))
					| POSINCR ->  let val1 = calculer (EXP exp) ia l sign in if estNoComp val1 then NOCOMP else evalexpression (Sum (val1, ConstInt ("1")) )
					| POSDECR ->  let val1 = calculer (EXP exp) ia l sign in if estNoComp val1 then NOCOMP else evalexpression (Diff (val1,ConstInt ("1")))	
			end
		| BINARY (op, exp1, exp2) ->
			if !vDEBUG then 
			begin 
				Printf.printf"binary\n";print_expression exp1 0;new_line ()	; 
				print_expression exp2 0;new_line () 
			end;
			let haspre = !hasSETCALL in

			hasSETCALL := false;
			let val1 = (calculer (EXP(exp1 )) ia l sign ) in 
			let hasSETCALLval1 = !hasSETCALL in
			let (estDefVal1, estPosVal1) =(estDefExp val1, estPositif val1) in
			

			hasSETCALL := false;			
			let val2 = calculer (EXP(exp2 )) ia l (sign * (signOf op )) in 			
			let (estDefVal2, estPosVal2) =(estDefExp val2, estPositif val2) in
			let hasSETCALLval2 = !hasSETCALL in

			hasSETCALL := haspre || hasSETCALLval1 || hasSETCALLval2;

			let isOkval1 =hasSETCALLval1 =false || (  estDefVal2  && estPosVal2) in
			let isOkval2 =   hasSETCALLval2 =false || (  estDefVal1  && estPosVal1) in
			let isOKAll = if 		(estDefVal1  = false && estDefVal2 = false) 
								|| 	(hasSETCALLval1 = false && hasSETCALLval2 = false) || (isOkval1 && isOkval2)then true else false in

(* (estDefVal1  = false && estDefVal2 = false) QUE DOIT8ON RETOURNER ?*) 
			let multop = (op=MUL)||(op=DIV)||(op=MOD)||(op=SHL)||(op=SHR) in

			let (val22,estPosVal22,val11,estPosVal11,oksign) =
			if multop then
			begin
				let (val22,estPosVal22) = if isOkval2 then (val2, estPosVal2) else 
					( let v = (calculer (EXP(exp2 )) ia l ((sign * (signOf op ))*(-1)) ) in
					  (v , estPositif v)	
					) in 
				let (val11,estPosVal11) = if isOkval1 then (val1, estPosVal1) else
					(
						let v = ( (calculer (EXP(exp1 )) ia l (sign*(-1) ))) in
						(v , estPositif v)	
					)  in 	

				let oksign =  ((estPosVal22 = estPosVal2)||isOkval1) && ((estPosVal11 = estPosVal1(* || estNul val1 || estNul val11*))||isOkval2) in 

			
				if oksign = false && multop then Printf.printf "problème inversion de sign\n";
				(val22,estPosVal22,val11,estPosVal11,oksign)
			end
			else  (val2, estPosVal2, val1, estPosVal1, true) in
		 
			(*Printf.printf"var2\n "; print_expTerm val2;new_line();*)
			if estNoComp val1 || estNoComp val2 || (multop && oksign = false )  then 
				if op = OR then 
					if estNoComp val1  then 
					 	if estNoComp val2 then NOCOMP 
						else (val2)
					else (val1)
				else NOCOMP  
			else
			begin
(*
if hasSETCALLval1 || hasSETCALLval2 then
begin 
				Printf.printf"binary calculer\n";print_expression exp1 0;new_line ()	; flush(); space();new_line();flush(); space();new_line();
				print_expression exp2 0;new_line () ;flush(); space();new_line();flush(); space();new_line();
Printf.printf"var1\n "; print_expTerm val1; new_line();
Printf.printf"var1\n "; print_expTerm val11; new_line();
Printf.printf"var2\n "; print_expTerm val2; new_line();
Printf.printf"var1\n "; print_expTerm val22; new_line();
			end;*)


				match op with
				ADD		->  evalexpression (Sum (val1, val2)) 	
				| SUB	->  evalexpression (Diff (val1, val2)) 	
				| MUL	->  if 	isOKAll	then evalexpression (Prod (val1, val2)) 
							else if isOkval1 = false && isOkval2 then evalexpression (Prod (val11, val2)) 
									else if isOkval2 = false && isOkval1 then evalexpression (Prod (val1, val22)) 
									
							else evalexpression (Prod (val11, val22))
				| DIV	->  if 	isOKAll	then  evalexpression (Quot (val1, val2)) 
							else 	if isOkval1 = false && isOkval2 then evalexpression (Quot (val11, val2)) 
								else 	if isOkval2 = false && isOkval1 then evalexpression (Quot (val1, val22)) 
										else evalexpression (Quot (val11, val22))
				| MOD	-> if 	isOKAll	then evalexpression (Mod (val1, val2)) 
							else 	if isOkval1 = false && isOkval2 then evalexpression (Mod (val11, val2)) 
								else 	if isOkval2 = false && isOkval1 then evalexpression (Mod (val1, val22)) 
										else evalexpression (Mod (val11, val22))				
				| SHL 	->  if 	isOKAll	then  evalexpression (Shl (val1, val2)) 
							else 	if isOkval1 = false && isOkval2 then evalexpression (Shl (val11, val2)) 
								else 	if isOkval2 = false && isOkval1 then evalexpression (Shl (val1, val22)) 
										else evalexpression (Shl (val11, val22))
				| SHR	->   if 	isOKAll	then  evalexpression (Shr (val1, val2)) 
							else 	if isOkval1 = false && isOkval2 then evalexpression (Shr (val11, val2)) 
								else 	if isOkval2 = false && isOkval1 then evalexpression (Shr (val1, val22)) 
										else evalexpression (Shr (val11, val22))				
				| EQ 	->  
			(*	Printf.printf"EQ exp1 , exp2\n";  print_expTerm val1; new_line(); print_expTerm val2;new_line();*)
				if hasSETCALLval1 || hasSETCALLval2 then NOCOMP
				else 
					if estBool val1 && estBool val2 then if val1 = val2   then Boolean(true)  else Boolean (false)
					else if estDefExp val1  &&  estDefExp val2 then 
					begin
										let diff = evalexpression (Diff (val1, val2 )) in
										if estNul diff then Boolean(true) 
										else Boolean (false)
									end
									else NOCOMP
				| NE-> 	
(*Printf.printf"NEQ exp1 , exp2\n";  print_expTerm val1; new_line(); print_expTerm val2;new_line();*)
					if hasSETCALLval1 || hasSETCALLval2 then NOCOMP
					else
						if estBool val1 && estBool val2 then if val1 = val2  then Boolean(false)  else Boolean (true)
						else if estDefExp val1 && estDefExp val2 then 
								if estNul (evalexpression (Diff (val1, val2 ))) then Boolean(false) 
								else Boolean (true)
						else NOCOMP
				| LT -> 
					if hasSETCALLval1 || hasSETCALLval2 then NOCOMP
					else if estDefExp val1 && estDefExp val2 then 
							if estPositif  (evalexpression (Diff (val1, val2 ))) then Boolean(false)  else Boolean (true)
						else NOCOMP
				| GT -> 
					if hasSETCALLval1 || hasSETCALLval2 then NOCOMP
					else 
						 if estDefExp val1 && estDefExp val2 then 
							if estStricPositif  (evalexpression (Diff (val1, val2 ))) then Boolean(true) 
							else Boolean (false)
						else NOCOMP
				| LE -> 
					if hasSETCALLval1 || hasSETCALLval2 then NOCOMP
					else 
						if estDefExp val1 && estDefExp val2 then 
							if estStricPositif (evalexpression (Diff (val1, val2 ))) then  Boolean(false) 
							else Boolean (true)
						else NOCOMP
				| GE -> 
					if hasSETCALLval1 || hasSETCALLval2 then NOCOMP
					else if estDefExp val1 && estDefExp val2 then 
							if estPositif (evalexpression (Diff (val1, val2 ))) then Boolean(true) 
							else Boolean (false)
						else NOCOMP
				| AND |OR ->
					let (resb1,comp1) = 
						(	if val1 = Boolean(true) || val1 = ConstInt ("1")  || val1 = ConstFloat("1.0")|| val1 = RConstFloat(1.0)
							then (true,true)
							else 
								if val1 = Boolean (false) || val1 = ConstInt ("0")  ||val1 = ConstFloat("0.0")||val1 = RConstFloat(0.0)						
								then (false, true) else (false, false) )in
					let (resb2, comp2) = 
						(	if val2 = Boolean(true) || val2 = ConstInt ("1")   || val2 = ConstFloat("1.0")|| val2 = RConstFloat(1.0)	
							then (true,true)
							else 
								if val2 = Boolean (false) || val2 = ConstInt ("0")  ||val2 = ConstFloat("0.0")||val2 = RConstFloat(0.0)						
								then (false, true) else (true, false) )in
(*estBoolOrVal*)
					if comp1 = false && comp2 = false then begin (*Printf.printf " NOCOMP AND OR \n";*)NOCOMP end
					else
					begin
						if op = OR then 
						begin 
								if comp1 = false  then Boolean(resb2 )
								else if comp2 = false then Boolean(resb1) else  Boolean(resb1 || resb2) 
						end
						else  if comp1 = false ||  comp2 = false then NOCOMP else   Boolean(resb1 && resb2) 
						
					end
				| BAND	| BOR| XOR	| ASSIGN | ADD_ASSIGN
				| SUB_ASSIGN| MUL_ASSIGN| DIV_ASSIGN | MOD_ASSIGN | BAND_ASSIGN	|BOR_ASSIGN
				| XOR_ASSIGN
				| SHL_ASSIGN| SHR_ASSIGN	->  NOCOMP
			end
			| QUESTION (_, _, _) ->	NOCOMP
			| CAST (_, e) ->		calculer (EXP(e)) ia l sign
			| CALL (exp, args) ->	
			(match exp with				
				VARIABLE("partieEntiereInf") -> 
					if !vDEBUG then
					begin Printf.printf"\ncalcul partieEntiereInf expression\n";
						print_expression (List.hd args) 0;		new_line ()	
					end;
					let val1 =  (calculer (EXP(List.hd args)) ia l sign)in
					let listeDesVar = listeDesVarsDeExpSeules  (List.hd args) in
					(*if estDefExp val1 then evalexpression (PartieEntiereInf (val1)) 
					else*)
					begin  								
						if (List.mem "EPSILON" listeDesVar) = false && (List.mem "EPSILONINT" listeDesVar) = false then
							 if estNoComp val1 then NOCOMP else  evalexpression (PartieEntiereInf (val1)) 							 	
						else
						begin
							let (vareps,isint) = if (List.mem "EPSILONINT" (listeDesVar)) then ("EPSILONINT",true) else ("EPSILON",false) in
							let sanseps =  remplacerValPar  vareps (CONSTANT (CONST_INT "0")) (List.hd args) in
							let valsanseps =(calculer (EXP(sanseps)) ia l sign) in
											(*+ or - espsilon ?*)
							let sanseps2 = remplacerValPar  vareps (CONSTANT (CONST_INT "1")) (List.hd args) in
							let valsanseps2  =(calculer (EXP(sanseps2)) ia l sign) in
							(*Printf.printf"\ncalcul partieEntiereInf expression avec epsilon\n";*)
						    (*print_expression (List.hd args) 0;		new_line ()	;*)

							let sens = if estDefExp valsanseps2 && getDefValue valsanseps2 < getDefValue valsanseps then 0 else 1 in
							let nexp= 

									if isint = false || sens = 1 then 
									(match valsanseps with
										ConstInt(_) 	-> if sens = 1 then ( valsanseps ) else( evalexpression( Diff (valsanseps, ConstInt("1"))) )
										| 	ConstFloat (f) ->	 let valeur = (float_of_string f) in 
																let pe = truncate valeur in
																let partieFract = valeur -. float_of_int pe in
																if sens = 1 then 
																	if partieFract+.min_float  = 1.0 then ConstInt(Printf.sprintf "%d" (pe+1))
																	else    ConstInt(Printf.sprintf "%d" pe)
																else if partieFract   = 0.0 then ConstInt(Printf.sprintf "%d" (pe-1))
																	else    ConstInt(Printf.sprintf "%d" pe)
										| 	RConstFloat (f) ->	  let valeur = (  f) in 
																let pe = truncate valeur in
																let partieFract = f -. float_of_int pe in
																 																if sens = 1 then ( 
																	if partieFract+.min_float  = 1.0 then ConstInt(Printf.sprintf "%d" (pe+1))
																	else    ConstInt(Printf.sprintf "%d" pe))
																else ( if partieFract   <min_float then ( ConstInt(Printf.sprintf "%d" (pe-1)))
																	else    ConstInt(Printf.sprintf "%d" pe))
										|_			-> 	  if estNoComp val1 then NOCOMP else  evalexpression (PartieEntiereInf (val1)) 
										)
									else if estNoComp val1 then NOCOMP else  evalexpression (PartieEntiereInf (valsanseps2)) 
									 in
				 						nexp				
							(*NOCOMP*)
						end
					end
															  
				|VARIABLE("partieEntiereSup") ->
					let val1 = evalexpression (calculer (EXP(List.hd args)) ia l sign)in
					let listeDesVar = listeDesVarsDeExpSeules  (List.hd args)  in
					(*if estDefExp val1 then evalexpression (PartieEntiereInf (val1)) 
					else*)
					begin  	
						if  List.mem "EPSILON" listeDesVar = false && List.mem "EPSILONINT" listeDesVar = false then 
							 if estNoComp val1 then NOCOMP else  evalexpression (PartieEntiereSup (val1)) 							 		
						else
						begin
							let (vareps,isint) = if (List.mem "EPSILONINT" (listeDesVar)) then ("EPSILONINT",true) else ("EPSILON",false) in
							let sanseps = remplacerValPar  vareps (CONSTANT (CONST_INT "0")) (List.hd args) in
							let valsanseps =(calculer (EXP(sanseps)) ia l sign) in
											(*+ or - espsilon ?*)
							let sanseps2 = remplacerValPar  vareps (CONSTANT (CONST_INT "1")) (List.hd args) in
							let valsanseps2  =(calculer (EXP(sanseps2)) ia l sign)  in
							let sens = if estDefExp valsanseps2 && getDefValue valsanseps2 < getDefValue valsanseps then 0 else 1 in

							let nexp=
								if isint = false || sens = 1 then 
								 (match valsanseps with
									ConstInt(_) 	-> if sens = 1 then evalexpression (Sum (valsanseps, ConstInt("1")))  else valsanseps
									| 	ConstFloat (f) ->	let valeur = (float_of_string f) in
															let pe = truncate valeur in
															let partieFract = valeur -. float_of_int pe in
															if sens = 1 then ConstInt(Printf.sprintf "%d" (pe+1))
															else 	if partieFract  = 0.0 then ConstInt(Printf.sprintf "%d" pe)
																	else 	ConstInt(Printf.sprintf "%d" (pe + 1)) (*is_integer_num*)
									| 	RConstFloat (f) ->	let valeur = (  f) in
															let pe = truncate valeur in
															let partieFract = f -. float_of_int pe in
															if sens = 1 then ConstInt(Printf.sprintf "%d" (pe+1))
															else 	if partieFract  = 0.0 then ConstInt(Printf.sprintf "%d" pe)
																	else 	ConstInt(Printf.sprintf "%d" (pe + 1)) (*is_integer_num*)
									|_			-> 	if estNoComp val1 then NOCOMP else  evalexpression (PartieEntiereSup (val1)) 
									) 
								else if estNoComp val1 then NOCOMP else  evalexpression (PartieEntiereSup (valsanseps2))  in
	 						nexp							 
						end
					end
					 
				|VARIABLE("pow10") ->
					let val1 = evalexpression (calculer (EXP(List.hd args)) ia l sign)in
					if estNoComp val1  then  NOCOMP  
					else  evalexpression (Puis  (val1, ConstInt("10"))	)
				|VARIABLE("pow") ->
					let val1 = evalexpression (calculer (EXP(List.hd args)) ia l sign)in
					if estNoComp val1  then 
					begin (*Printf.printf"NO COMP partieEntiereSup\n";	*)NOCOMP end
					else
					begin
						let suite = List.tl args in
						let val2 = (calculer (EXP(List.hd suite )) ia l sign)in
						if estNoComp val2   then  NOCOMP else evalexpression (Puis  (val1, val2)) 
					end
				|VARIABLE("MAXIMUM") ->
					let val1 = evalexpression (calculer (EXP(List.hd args)) ia l sign)in
					if estNoComp val1  then 
					begin (*Printf.printf"NO COMP partieEntiereSup\n";	*)NOCOMP end
					else
					begin
						let suite = List.tl args in
						let val2 = (calculer (EXP(List.hd suite )) ia l sign)in
						if estNoComp val2   then  NOCOMP  
						else evalexpression (Maximum  (val1, val2)) 
					end		
				|VARIABLE("MINIMUM") ->
					let val1 = evalexpression (calculer (EXP(List.hd args)) ia l sign) in
					if estNoComp val1  then 
					begin (*Printf.printf"NO COMP partieEntiereSup\n";	*)NOCOMP end
					else
					begin 
						let suite = List.tl args in
						let val2 = (calculer (EXP(List.hd suite )) ia l sign)in
					
						if estNoComp val2   then   NOCOMP 
						else evalexpression (Minimum  (val1, val2)) 
					end
					
				|VARIABLE("SET") ->(*pour le moment deux arg*)
					hasSETCALL:=true;
					let val1 = evalexpression (calculer (EXP(List.hd args)) ia l sign) in
					if estNoComp val1  then 
					begin (*Printf.printf"NO COMP partieEntiereSup\n";	*)NOCOMP end
					else
					begin
						let suite = List.tl args in
						let val2 = (calculer (EXP(List.hd suite )) ia l sign)in
					
						if estNoComp val2   then   NOCOMP   
						else (* *)
						begin
						(*	Printf.printf"set\n"; if sign = 1 then Printf.printf "max\n"else Printf.printf "min\n";	print_expTerm  val1;  space(); new_line() ;flush();print_expTerm  val2;  space(); new_line() ;flush();*)
						 	if sign = 1 then evalexpression (Maximum  (val1, val2))  else 
								if sign = -1 then evalexpression (Minimum  (val1, val2)) else NOCOMP
						end
					end
					
				|VARIABLE("log") ->
					let val1 = evalexpression (calculer (EXP(List.hd args)) ia l sign)in
					if estNoComp val1   then 
					begin (*Printf.printf"NO COMP partieEntiereSup\n";	*)NOCOMP end
					else evalexpression (Log (val1)) 	
				|VARIABLE("log10") ->
					let val1 = evalexpression (calculer (EXP(List.hd args)) ia l sign)in
					if estNoComp val1   then 
					begin (*Printf.printf"NO COMP partieEntiereSup\n";	*)NOCOMP end
					else evalexpression (Quot (Log (val1), Log(ConstInt("10") ) ) 	)
				|VARIABLE("log2") -> 
					let val1 = evalexpression (calculer (EXP(List.hd args)) ia l sign)in
					if estNoComp val1   then 
					begin (*Printf.printf"NO COMP partieEntiereSup\n";	*)NOCOMP end
					else evalexpression  (Quot (Log (val1), Log(ConstInt("2") ) ) 	)
				|VARIABLE("max") ->
					let val1 = evalexpression (calculer (EXP(List.hd args)) ia l sign)in
					if estNoComp val1   then 
					begin (*Printf.printf"NO COMP partieEntiereSup\n";	*)NOCOMP end
					else val1
				|VARIABLE("SYGMA") -> 		
				 begin
					if !vDEBUG then Printf.printf"SYGMA\n";
					let varexp = ( List.hd args )in
				 	let suite = List.tl args in
					match varexp with	
					VARIABLE (var) ->												
						let max = (calculer (EXP(List.hd suite )) ia l 1)in
						if  estNoComp max   then NOCOMP
						else
						begin
							if !vDEBUG then
							begin
								Printf.printf"SYGMA simplifier\n";
								Printf.printf"SYGMA pour %s =\n" var;
								Printf.printf"SYGMA pour %s expression simplifier\n" var;
								Printf.printf "evalexpression max\n"; 
								print_expTerm max; new_line ();
								print_expression (List.hd (List.tl suite) ) 0;new_line ();
							end;

					    	let listvar = listeDesVarsDeExpSeules (List.hd (List.tl suite)) in

							let (expToMax,has,expAvec) = 
								if List.mem "EPSILON" listvar then 
									((*Printf.printf "has epsilon\n";*)
									(remplacerValPar  "EPSILON" (CONSTANT (CONST_INT "0")) (List.hd (List.tl suite)), true,List.hd (List.tl suite)))
								else 	
									if List.mem "EPSILONINT" listvar then 
										(remplacerValPar  "EPSILONINT" (CONSTANT (CONST_INT "0")) (List.hd (List.tl suite)), true,List.hd (List.tl suite))
									else  (List.hd (List.tl suite) , false,(List.hd (List.tl suite)))  in
							if List.mem var l then NOCOMP
							else
							begin
								let expE = (calculer  (EXP(expToMax))ia  (List.append [var] l) 1) in
								if  estNoComp expE   then  
								begin 
									 
												let (has, e1, e2 )= hasMinimum   (List.hd (List.tl suite)) in
												if has then
												begin
													(*Printf.printf "h&s minimum\n";*)
												 	let terme1 = 	calculer(EXP( CALL (VARIABLE("SYGMA"),List.append  [VARIABLE (var)]
																	(List.append [List.hd suite]
																	[replaceMinimum (List.hd (List.tl suite)) 1	])) )) ia l 1  in
													let terme2 = 	calculer(EXP( CALL (VARIABLE("SYGMA"),List.append  [VARIABLE (var)]
																	(List.append [List.hd suite]
																	[replaceMinimum (List.hd (List.tl suite)) 2	])) )) ia l 1  in
													(*print_expTerm terme1; new_line ();
													print_expTerm terme2; new_line ();*)
													calculer(EXP(
														CALL(VARIABLE("MINIMUM") ,  List.append  [expressionEvalueeToExpression terme1]  [expressionEvalueeToExpression terme2 ] ))) ia l 1
												end else NOCOMP
										 	 
								end
								else
								begin
									let val1 = simplifier var max expE ia has (calculer  (EXP(expAvec))ia l 1) in
									if  estNoComp val1 then   Sygma (var ,ConstInt("0")(* ou 1 voir*), max,expE)(* NOCOMP*)
									else	val1
								end	
							end
						end			
					|_-> NOCOMP
				end					
				|VARIABLE("MAX") -> 		
				begin
					if !vDEBUG then Printf.printf"MAX\n";
				 	let varexp = ( List.hd args )in
				 	let suite = List.tl args in
					match varexp with
					VARIABLE (var) ->		
						let listvar = listeDesVarsDeExpSeules (List.hd (List.tl suite)) in					
						let (expToMax,has,expAvec) = 
							if List.mem "EPSILON" listvar then 
								((remplacerValPar  "EPSILON" (CONSTANT (CONST_INT "0")) (List.hd (List.tl suite)), true,(List.hd (List.tl suite))))
							else
								if List.mem "EPSILONINT" listvar then 
									(remplacerValPar  "EPSILONINT" (CONSTANT (CONST_INT "0")) (List.hd (List.tl suite)), true,List.hd (List.tl suite))
								else (List.hd (List.tl suite) , false,(List.hd (List.tl suite)))  in
						if List.mem var listvar then
						begin									
							let max = (calculer (EXP(List.hd suite )) ia l 1)in
							if  estNoComp max   then NOCOMP
							else
							begin
								if !vDEBUG then
								begin
									Printf.printf"MAX simplifier\n";
									Printf.printf"MAX pour %s = O..\n" var;	
									print_expTerm max; new_line ();Printf.printf" ( " ;
									print_expression (List.hd (List.tl suite) ) 0;new_line ();
									Printf.printf" ) " ;
								end;
								if estDefExp max && estNul max then 
								begin
									(*Printf.printf "remplacer max\n"	;*)
									calculer  (EXP (remplacerValPar0 var (List.hd (List.tl suite)) )) 	ia l sign
								end
								else
								begin
									let expE = (calculer  (EXP(expToMax))ia l 1) in
									if estNoComp expE  then
									begin (*Printf.printf"MAX MINIMUM\n";*)
										 
												let (has, e1, e2 )= hasMinimum   (List.hd (List.tl suite)) in
												if has then
												begin
													(*Printf.printf "h&s minimum\n";*)
													let terme1 = 	calculer(EXP( CALL (VARIABLE("MAX"),List.append  [VARIABLE (var)]
																	(List.append [List.hd suite]
																	[replaceMinimum (List.hd (List.tl suite)) 1	])) )) ia l 1  in
													let terme2 = 	calculer(EXP( CALL (VARIABLE("MAX"),List.append  [VARIABLE (var)]
																	(List.append [List.hd suite]
																	[replaceMinimum (List.hd (List.tl suite)) 2	])) )) ia l 1  in
													(*print_expTerm terme1; new_line ();
													print_expTerm terme2; new_line ();*)
													calculer(EXP(
														CALL(VARIABLE("MINIMUM") ,  List.append  [expressionEvalueeToExpression terme1]  [expressionEvalueeToExpression terme2 ] ))) ia l 1 
												
 
												end else NOCOMP
										 	 
									end
									else
									begin		
										let val1 = simplifierMax var max expE ia has (calculer  (EXP(expAvec))ia l 1)  in
										(*Printf.printf"calcul MAX pour %s =\n" var; 
										print_expression expAvec 0;
										print_expTerm val1; new_line ();
										Printf.printf"MAX apres calcul =\n";*)
										if  estNoComp val1 then  NOCOMP
											(*Max (var ,ConstInt("0")(* ou 1 voir*), max,expE)*)
										else	val1
									end	
								end
							end
						end	
						else calculer  (EXP (List.hd (List.tl suite)) ) ia l sign 
																																			
					|_-> NOCOMP
				end
				|_-> (*|VARIABLE("MAX") -> *)	NOCOMP
			)
			| COMMA e ->					NOCOMP
			| CONSTANT cst -> 													
				(	match cst with
						CONST_INT i 	->	

						  let res =	(ConstInt( (removeSpecifieur  i true)))  in res
						| RCONST_INT i 	->	  	(ConstInt(Printf.sprintf "%d" ( i )))
						| CONST_FLOAT r ->	   (ConstFloat( (removeSpecifieur r false)))
						| RCONST_FLOAT r ->	   	 (RConstFloat(r))
						
						| CONST_CHAR _ 	|CONST_STRING _ | CONST_COMPOUND _ ->	NOCOMP
				)
			| VARIABLE (s) ->		 (Var(s))
			| _ -> 	NOCOMP

	)
|	MULTIPLE -> NOCOMP

 

and roindex var l i=
   List.find  (fun aSC ->  match aSC with ASSIGN_SIMPLE (id, _) ->  false|ASSIGN_DOUBLE (id, index, _)-> (id = var) && eqindex index i| ASSIGN_MEM (id, e, _)	-> 
(*
let (tab1,_, _) =getArrayNameOfexp (expVaToExp e) in
 if tab1 = id &&*)

					eqmemindex id var i e


) l


and eqmemindex id var i e =
if id = var&& eqindex e i then true
else
begin
	let (tab1,_, _) =getArrayNameOfexp (expVaToExp e) in

	let (index , _) = consArrayFromPtrExp (expVaToExp e )  tab1 in

	if tab1 = "" then false else tab1 = var && eqindex (EXP index) i

end



and eqindex i j =
if i = j then begin (*Printf.printf " index egaux \n" ;*) true end else 
begin
	let i1 = calculer i !infoaffichNull [] 1 in
	let ii1 = calculer j !infoaffichNull  [] 1 in
	if estNoComp i1 || estNoComp ii1 then false (*en fait en ne peut pas répondre*)
	else if  estNul (evalexpression (Diff (i1, ii1 ))) then  begin (*Printf.printf " index egaux \n" ;*) true end  else false
end

and calculer_simple expVA = calculer expVA CROISSANT [] 1
and calculer_avec_sens expVA sens = calculer expVA sens [] 1
and estVarDsExpEval var expre =
match expre with
		NOCOMP 			-> false
	 	| Sum (f, g) 	->  (estVarDsExpEval var f) || (estVarDsExpEval var g)
		| Diff (f, g) 	->  (estVarDsExpEval var f)  || (estVarDsExpEval var g)
		| Prod (f, g)  	->  (estVarDsExpEval var f)  || (estVarDsExpEval var g)
		| Shr (f, g)  	->  (estVarDsExpEval var f)  || (estVarDsExpEval var g)
		| Shl (f, g)  	->  (estVarDsExpEval var f)  || (estVarDsExpEval var g)
		| Quot (f, g)	->  (estVarDsExpEval var f)  || (estVarDsExpEval var g)
		| Puis (f, g)	->  (estVarDsExpEval var f)  || (estVarDsExpEval var g)
		| Mod (f, g)	->  (estVarDsExpEval var f)  ||(estVarDsExpEval var g)
		| ConstInt(_) 	->  false
		| ConstFloat (_)->  false
		| RConstFloat (_)->  false
		| Boolean (_) -> 	false
		| Var (s) -> 		if s = var then true else false
		| PartieEntiereSup (e)-> 	(estVarDsExpEval var e) 
		| Log (e)-> 		(estVarDsExpEval var e) 
	    | PartieEntiereInf (e)-> 	(estVarDsExpEval var e) 
   		| Sygma (v,min,max,exp)-> (estVarDsExpEval var min)  || (estVarDsExpEval var max)|| (estVarDsExpEval var exp) || v = var
    	| Max (v,min,max,exp)-> (estVarDsExpEval var min) || (estVarDsExpEval var max)|| (estVarDsExpEval var exp)|| v = var
  		| Eq1 (v)-> 		 (estVarDsExpEval var v) 
  		| Maximum (f, g)  -> (estVarDsExpEval var f) || (estVarDsExpEval var g)
		| Minimum (f, g)  -> (estVarDsExpEval var f) || (estVarDsExpEval var g)

and estAffine var expre =
if !vDEBUG then Printf.printf"SYGMA simplifier dans affine\n";
	match expre with
		NOCOMP -> false
	 	| Sum (f, g) 	->  (estAffine var f) && (estAffine var g)
		| Diff (f, g) 	->  (estAffine var f) && (estAffine var g)
		| Prod (f, g)  ->  	if (estVarDsExpEval var f = false) then (estAffine var g)
							else if (estVarDsExpEval var g = false) then (estAffine var f)  else false
		| Puis (f, g) ->  	if (estVarDsExpEval var f = false) && (estVarDsExpEval var g = false) then true else false
		| Quot (f, g)	->  if (estVarDsExpEval var g = false) then (estAffine var f)  else false
		| Shr (f, g)  ->	if (estVarDsExpEval var f = false) then (estAffine var g)
							else if (estVarDsExpEval var g = false) then (estAffine var f) else false
		| Shl (f, g)	->  if (estVarDsExpEval var g = false) then (estAffine var f)  else false
		| Mod (f, g)	->  if (estVarDsExpEval var g = false)then (estAffine var f)  else false
		| ConstInt(_)| Boolean(_) | ConstFloat (_) | Var (_) -> 		true
		| RConstFloat (_)  -> 		true
		| PartieEntiereSup (e)->  (estAffine var e) (*revoir*)
	    | PartieEntiereInf (e)->  (estAffine var e)
   	    | Sygma (v,_,_,_)-> 
			if v = var then false else
			if (estVarDsExpEval var expre = false) then true else false
  	    | Max (_,_,_,_)->   if (estVarDsExpEval var expre = false) then true else false
		| Log (_)->      	if (estVarDsExpEval var expre = false) then true else false
 		| Eq1 (v)-> 		(estAffine var v)
  		| Maximum (f, g)  -> if (estVarDsExpEval var f = false) && (estVarDsExpEval var g = false) then true else false 
  		| Minimum (f, g)  -> if (estVarDsExpEval var f = false) && (estVarDsExpEval var g = false) then true else false 
	
and remplacerVpM var max expre =
if !vDEBUG then Printf.printf"SYGMA simplifier avant remplacerVpM\n";
	match expre with
		  ConstInt(_)->evalexpression(Prod (expre,Sum(max, ConstInt("1"))))
		| ConstFloat (_)->evalexpression(Prod (expre, Sum(max, ConstInt("1")) )) 
		| RConstFloat (_)->evalexpression(Prod (expre, Sum(max, ConstInt("1")) )) 	
		| NOCOMP		->NOCOMP	
		| Var (s) -> if s = var then Quot ( Prod (max,(Sum (max, ConstInt("1"))) ) ,ConstInt("2")) (* n*(n+1)/2*)
					 else evalexpression(Prod (expre,Sum(max, ConstInt("1"))))
		| Sum (f, g)  -> Sum((remplacerVpM var max f) , (remplacerVpM var max g))
		| Diff (f, g)  -> Diff((remplacerVpM var max f) , (remplacerVpM var max g))
		| Prod (f, g)  -> if (estVarDsExpEval var g= false) then Prod((remplacerVpM var max f) , g)
								else Prod(f , (remplacerVpM var max g))
		| Shr (f, g)  -> if (estVarDsExpEval var g= false) then Shr((remplacerVpM var max f) , g)
								else Shr(f , (remplacerVpM var max g))
		| Mod (f, g)  	-> Mod((remplacerVpM var max f) ,  g)
		| Quot (f, g)  -> Quot((remplacerVpM var max f) ,  g)
		| Puis (_, _)  -> expre (* variable pas dans exp sinon pas affine *)
		| Shl (f, g)  -> Shl((remplacerVpM var max f) ,  g)
		| PartieEntiereSup (e)-> PartieEntiereSup(remplacerVpM var max e)
	    | PartieEntiereInf (e)-> PartieEntiereInf(remplacerVpM var max e)
	    | Log (e)-> Log(remplacerVpM var max e)
   	    | Sygma (v,min,maxi,e)-> Sygma(v, min,(remplacerVpM var max maxi) , (remplacerVpM var max e))
		| Max (v,min,maxi,e)-> Max(v, min,(remplacerVpM var max maxi) , (remplacerVpM var max e))
 		| Eq1 (v)-> (remplacerVpM var max v) 
		| Maximum (f, g)  ->  Maximum((remplacerVpM var max f) , (remplacerVpM var max g))
		| Minimum (f, g)  ->  Minimum((remplacerVpM var max f) , (remplacerVpM var max g))
		| _->expre


and remplacerVal var max expre =
(*if !vDEBUG then Printf.printf"SYGMA simplifier avant remplacerVpM\n";*)
	match expre with
		  ConstInt(_) | ConstFloat (_) | Boolean (_)->expre
		| RConstFloat (_) ->expre
		| NOCOMP			->NOCOMP	
		| Var (s) 	  -> if s = var then max else expre
		| Sum (f, g)  -> Sum((remplacerVal var max f) , (remplacerVal var max g))
		| Diff (f, g) -> Diff((remplacerVal var max f) , (remplacerVal var max g))
		| Prod (f, g) -> Prod((remplacerVal var max f) , (remplacerVal var max g))
		| Shr (f, g)  -> Shr((remplacerVal var max f) , (remplacerVal var max g))
		| Shl (f, g)  -> Shl((remplacerVal var max f) , (remplacerVal var max g))	
		| Mod (f, g)  -> Mod((remplacerVal var max f) , (remplacerVal var max g))
		| Quot (f, g) -> Quot((remplacerVal var max f) , (remplacerVal var max g))
		| PartieEntiereSup(e)-> PartieEntiereSup(remplacerVal var max e)
	    | PartieEntiereInf(e)-> PartieEntiereInf(remplacerVal var max e)
		| Log (e)	  -> Log(remplacerVal var max e)
   	    | Sygma (v,min,maxi,e)-> 
			if var <> v then Sygma(v, min,(remplacerVal var max maxi) , (remplacerVal var max e)) else expre
		| Max (v,min,maxi,e)-> 
			if var <> v then Max(v, min,(remplacerVal var max maxi) , (remplacerVal var max e)) else expre
		| Puis (v,e)  ->
			let (val1,val2) = (evalexpression (remplacerVal var max v) , evalexpression (remplacerVal var max e)) in
		if estNoComp val1 || estNoComp val2 then  NOCOMP else  Puis(val1 , val2)  
 		| Eq1 (v)		-> (remplacerVal var max v) 
		| Maximum (f, g)-> Maximum((remplacerVal var max f) , (remplacerVal var max g))
		| Minimum (f, g)-> Minimum((remplacerVal var max f) , (remplacerVal var max g))
		

and calculaetbAffineForne x expre = (* a*x+b d'une foction affine en x *)
	match expre with
		NOCOMP -> (ConstInt("0"),ConstInt("0"))
		| Boolean (_)->(ConstInt("0"),ConstInt("0"))
	 	| Sum (f, g) 	->  
			if (estVarDsExpEval x f = false) then
			begin 
				if (estVarDsExpEval x g = false) then 
					(ConstInt("0"), (evalexpression (Sum (evalexpression f, evalexpression g))))
				else 
				begin
					let (a1, b1) = calculaetbAffineForne x g in (a1 , evalexpression (Sum (evalexpression f, b1)) )
				end
			end
			else 
			begin
				if (estVarDsExpEval x g = false) then 
				begin
					let (a1, b1) = calculaetbAffineForne x f in (a1 , evalexpression (Sum (evalexpression g, b1)) )
				end
				else
				begin
					let (a1, b1) = calculaetbAffineForne x f in
					let (a2, b2) =  calculaetbAffineForne x g in
					(evalexpression (Sum (a1, a2)),evalexpression( Sum (b1, b2)) ) 
							(*a1x+b1+a2x+b2 =(a1+a2)x+(b1+b2)*)
				end
			end
		| Diff (f, g) 	->  
			if (estVarDsExpEval x f = false) then
			begin 
				if (estVarDsExpEval x g = false) then 
					( ConstInt("0"),
					 (evalexpression (Sum (evalexpression f, evalexpression (Diff (ConstInt("0"),evalexpression g)) ))))
				else 
				begin
					let (a1, b1) = calculaetbAffineForne x g in
					(
						evalexpression (Diff (ConstInt("0"), a1)),
						evalexpression (Sum  (evalexpression f,   evalexpression (Diff (ConstInt("0"), b1)) )))
				end
			end
			else 
			begin
				if (estVarDsExpEval x g = false) then 
				begin
					let (a1, b1) = calculaetbAffineForne x f in
					(a1 , evalexpression (Sum  (b1,  evalexpression (Diff (ConstInt("0"),evalexpression g)) )))
				end
				else  
				begin
					let (a1, b1) = calculaetbAffineForne x f in
					let (a2, b2) =  calculaetbAffineForne x g in
					( evalexpression (Sum (a1, evalexpression (Diff (ConstInt("0"),a2)))),
					  evalexpression( Sum (b1, evalexpression (Diff (ConstInt("0"),b2))) )) 
								(*a1x+b1+a2x+b2 =(a1+a2)x+(b1+b2)*)
				end
			end
		| Prod (f, g)  ->  
			if (estVarDsExpEval x f = false) then (* f constante*) 
			begin  
			 	if (estVarDsExpEval x g = false) then 
					(ConstInt("0"),evalexpression (Prod (evalexpression f, evalexpression g) ))
				else
				begin 
					let (a1, b1) = calculaetbAffineForne x g in
					(evalexpression (Prod (evalexpression f, a1)), evalexpression (Prod (evalexpression f, b1)))
				end
			end
			else (
				if (estVarDsExpEval x g = false) then 
				begin 
					let (a1, b1) = calculaetbAffineForne x f in
					(evalexpression (Prod (evalexpression g, a1)), evalexpression (Prod (evalexpression g, b1)))
				end
				else (* Printf.printf " affine prod cas 3 \n";*) (ConstInt("0"),ConstInt("0") ) )
		| Shr (f, g)  -> 
				
				if (estVarDsExpEval x g = false) then 
				begin
					if (estVarDsExpEval x f = false) then 
						(ConstInt("0"),evalexpression (Shr (evalexpression f, evalexpression g) ))
					else					
					begin 
						let (a1, b1) = calculaetbAffineForne x f in
						let (fa1, fb1) = (( match a1 with  ConstInt(j) -> ConstFloat(j) |_-> a1),
										  ( match b1 with  ConstInt(j) -> ConstFloat(j) |_-> b1) ) in
						let eg = evalexpression (Puis (ConstInt("2"), g)) in


						(evalexpression (Quot ( fa1,  eg)), evalexpression(Quot ( fb1, eg)))
					end
				end
				else (ConstInt("0"),ConstInt("0"))
		| Quot (f, g)	->   
				if (estVarDsExpEval x g = false) then 
				begin
					if (estVarDsExpEval x f = false) then 
						(ConstInt("0"),evalexpression (Quot (evalexpression f, evalexpression g) ))
					else					
					begin
						let (a1, b1) = calculaetbAffineForne x f in
						let (fa1, fb1) = (( match a1 with  ConstInt(j) -> ConstFloat(j) |_-> a1),
										  ( match b1 with  ConstInt(j) -> ConstFloat(j) |_-> b1) ) in
						(evalexpression (Quot ( fa1, evalexpression g)), evalexpression(Quot ( fb1, evalexpression g)))
					end
				end
				else (ConstInt("0"),ConstInt("0"))
		|  Puis (f, g)	->   (ConstInt("0"),ConstInt("0"))
		|  Mod (f, g)	->  
				if (estVarDsExpEval x g = false) then 
				begin
					if (estVarDsExpEval x f = false) then 
						(ConstInt("0"),evalexpression (Mod (evalexpression f, evalexpression g) ))
					else					
					begin
						let (a1, b1) = calculaetbAffineForne x f in
						let (fa1, fb1) = (( match a1 with  ConstInt(j) -> ConstFloat(j) |_-> a1),
										  ( match b1 with  ConstInt(j) -> ConstFloat(j) |_-> b1) ) in
						(evalexpression (Mod ( fa1, evalexpression g)), evalexpression(Mod ( fb1, evalexpression g)))
					end
				end
				else (ConstInt("0"),ConstInt("0"))
		|  Shl (f, g)	->    
				if (estVarDsExpEval x f = false) then (* f constante*) 
				begin
					 if (estVarDsExpEval x g = false) then 
						(ConstInt("0"),evalexpression (Shl (evalexpression f, evalexpression g) ))
					 else
					 begin (*Printf.printf "pas dans f mais dans g\n";*)
						(*let (a1, b1) = calculaetbAffineForne x g in
						
						 (evalexpression (Shl (evalexpression f, a1)), evalexpression (Shl (evalexpression f, b1)))*)(ConstInt("0"),ConstInt("0"))
					 end
				end
				else
				 	if (estVarDsExpEval x g = false) then 
					begin
						 let eg = evalexpression (Puis (ConstInt("2"), g)) in
						 let (a1, b1) = calculaetbAffineForne x f in
						 (evalexpression (Prod (evalexpression a1, eg)), evalexpression (Prod (evalexpression b1, eg)))
					end
					else (ConstInt("0"),ConstInt("0"))


		| ConstInt(_) -> (ConstInt("0"),evalexpression expre)
		| ConstFloat (_) -> (ConstInt("0"),evalexpression expre)
		| RConstFloat (_) -> (ConstInt("0"),evalexpression expre)
		| Var (v) -> if v = x then (ConstInt("1"), ConstInt("0")) else (ConstInt("0"),Var (v))
		| PartieEntiereSup (e)->  	(* evalexpression (PartieEntiereSup*)
									let (a1, b1) =calculaetbAffineForne x e 	in 
									( a1, evalexpression (PartieEntiereSup b1))		
	    | PartieEntiereInf (e)->  	 	let (a1, b1) =calculaetbAffineForne x e 	in 
									( a1, evalexpression (PartieEntiereInf b1))
	    | Log (e)->  	 	let (a1, b1) =calculaetbAffineForne x e 	in 
									( a1, evalexpression (Log b1))
   	    | Sygma (_,_,_,_)->     (ConstInt("0"),evalexpression expre)
		| Max (_,_,_,_)->     (ConstInt("0"),evalexpression expre)	
		| Eq1 (v)->  calculaetbAffineForne x v 		
		|  Maximum (f, g)  ->  
			if (estVarDsExpEval x f = false) && (estVarDsExpEval x g = false) then 
					(	ConstInt("0"), (evalexpression  (Maximum (evalexpression f, evalexpression g)) ))
			else (	ConstInt("0"), ConstInt("0"))
		|  Minimum (f, g)  ->  
			if (estVarDsExpEval x f = false) && (estVarDsExpEval x g = false) then 
					(	ConstInt("0"), (evalexpression  (Minimum (evalexpression f, evalexpression g)) ))
			else (	ConstInt("0"), ConstInt("0"))

and sensVariation var max expre ia =
	if (estAffine var expre)   then 
	begin 
		let (a,b) = calculaetbAffineForne var expre in		
		let (var1, var2) = (evalexpression a , evalexpression b) in
		if  (estStricPositif var1) then CROISSANT
		else begin if (estNul var1) then  CONSTANTE  else DECROISSANT end
	end
	else 
	begin
	let sensRes =
	(
		match expre with
			NOCOMP -> NONMONOTONE
		 	| Sum (f, g) 	->  
				let sensf = sensVariation var max f ia in
				let sensg =  sensVariation var max g ia in
				(*Printf.printf "Sum sens f g\n" ; printSens sensf; printSens sensg;*)
				if (sensf = sensg) then sensf 
				else if (sensf <> NONMONOTONE) && (sensg = CONSTANTE) then  sensf
					 else if (sensg <> NONMONOTONE) && (sensf = CONSTANTE) then  sensg
						  else NONMONOTONE
			| Diff (f, g) 	->
				let sensf = sensVariation var max f ia in
				let sensg =  sensVariation var max g ia in
				(*Printf.printf "Diff sens f , g\n" ;printSens sensf; printSens sensg;*)
				(match sensf with
					CONSTANTE ->
						if   (CONSTANTE = sensg )  then CONSTANTE
						else (* sensg != CONSTANTE *)
							if (sensg =  DECROISSANT) then  CROISSANT  
							else if sensg  = CROISSANT then DECROISSANT else NONMONOTONE
				   | NONMONOTONE -> NONMONOTONE
				   | CROISSANT ->
						if ( sensg = CONSTANTE) || (sensg =  DECROISSANT) then  CROISSANT  else NONMONOTONE
						
					| DECROISSANT->
						if ( sensg = CONSTANTE) || (sensg =  CROISSANT) then  DECROISSANT   else NONMONOTONE
				)
			| Prod (f, g)| Shr (f, g) |  Puis (f, g)  ->  
				let sensf = sensVariation var max f ia in
				let sensg =  sensVariation var max g ia in
				(*Printf.printf "Prod sens f , g\n" ;printSens sensf; printSens sensg;*)
				(match sensf with
					CONSTANTE ->
						if   (CONSTANTE = sensg )  then CONSTANTE
						else (* sensg != CONSTANTE *)
							if estNul f then  CONSTANTE 
							else 
								if (estStricPositif f) then  sensg
								else if (sensg = CROISSANT) then DECROISSANT else CROISSANT
				   | NONMONOTONE -> NONMONOTONE
				   | CROISSANT ->
						if sensg  = CROISSANT then CROISSANT
						else 
							if ( sensg = CONSTANTE) then
								if (estStricPositif g) then  sensf
								else  if estNul g then  CONSTANTE else DECROISSANT  
							else NONMONOTONE
						
					| DECROISSANT->
						if (sensg  = DECROISSANT)  then DECROISSANT
						else if sensg  = CONSTANTE then
								if (estStricPositif g)   then DECROISSANT
								else  if (estNul g) then  CONSTANTE else CROISSANT 	
							 else NONMONOTONE
				)
			| Quot (f, g)	|  Mod (f, g) 	|  Shl (f, g)->  
				let sensf = sensVariation var max f ia in
				let sensg =  sensVariation var max g ia in
(*Printf.printf "Quot sens f , g\n" ;printSens sensf; printSens sensg;*)
				(match sensf with
					CONSTANTE ->
						if   (CONSTANTE = sensg )  then CONSTANTE
						else 
							if estNul f then  CONSTANTE 
							else 
								if (estStricPositif f) then  
									if sensg = CROISSANT then DECROISSANT else CROISSANT 
								else  sensg
				   | NONMONOTONE -> NONMONOTONE
				   | CROISSANT ->
						if sensg  = DECROISSANT then CROISSANT
						else if sensg  = CONSTANTE then
								if (estStricPositif g)   then CROISSANT
								else DECROISSANT
							else NONMONOTONE
					| DECROISSANT->
						if (sensg  = CROISSANT)  then DECROISSANT
						else if sensg  = CONSTANTE then
								if (estStricPositif g)   then DECROISSANT
								else CROISSANT
							else NONMONOTONE
				)				 
			| ConstInt(_) | ConstFloat (_)  -> CONSTANTE
			| RConstFloat (_)  -> CONSTANTE
			| Var (_) ->  CROISSANT 
			| PartieEntiereSup (e)  | PartieEntiereInf (e)  | Log (e)->  	 	sensVariation var max e ia
	   	    | Sygma (_,_,_,exp)->    let sensexp = sensVariation var max exp ia  in
									 if (sensexp = CROISSANT  ) || (sensexp = CONSTANTE  )then CROISSANT
									 else NONMONOTONE
			| Max (_,_,_,exp)->      sensVariation var max exp ia 
			| Eq1 (v)->  NONMONOTONE 		
			|  Maximum (f, g)  ->  
				let sensf = sensVariation var max f ia in
				let sensg =  sensVariation var max g ia in
				
				if (sensf  = CONSTANTE) && (sensg  = CONSTANTE ) then CONSTANTE
				else	if ((sensf  = CROISSANT) || (sensf  = CONSTANTE) )
								&& ((sensg  = CROISSANT) || (sensg  = CONSTANTE))  then CROISSANT
					else if ((sensf  = DECROISSANT) || (sensf  = CONSTANTE)) &&
						 ((sensg  = DECROISSANT) ||(sensg  = CONSTANTE))  then DECROISSANT  else NONMONOTONE
		   |  Minimum (f, g)  ->  
				let sensf = sensVariation var max f ia in
				let sensg =  sensVariation var max g ia in
				
				if (sensf  = CONSTANTE) && (sensg  = CONSTANTE ) then CONSTANTE
				else	if ((sensf  = CROISSANT) || (sensf  = CONSTANTE) )
								&& ((sensg  = CROISSANT) || (sensg  = CONSTANTE))  then CROISSANT
					else if ((sensf  = DECROISSANT) || (sensf  = CONSTANTE)) &&
						 ((sensg  = DECROISSANT) ||(sensg  = CONSTANTE))  then DECROISSANT  else NONMONOTONE	
	  	   | Boolean (_)->NONMONOTONE
	) in
(*printSens sensRes; Minimum*)
sensRes
	end
(* terminer *)
and estCroissantOuCte var max expre ia =
let sens = sensVariation  var max expre ia in
sens = CROISSANT || sens = CONSTANTE  

and estDecroissantOuCte var max expre ia =
let sens = sensVariation  var max expre ia in
sens = DECROISSANT || sens = CONSTANTE 

and simplifierSYGMA var max expre ia witheps exprea=
let res = (
	match expre with
		NOCOMP -> NOCOMP
	 	| Sum (f, g) 	->  
			if (estVarDsExpEval var f = false) then
			begin 
				if (estVarDsExpEval var g = false) then  
					evalexpression (Prod (Sum(max,ConstInt("1")), expre))
				else 
					evalexpression ( Sum ( evalexpression (Prod (Sum(max,ConstInt("1")), f)),
										  simplifierSYGMA var max g ia	witheps exprea))
			end
			else 
			begin
				if (estVarDsExpEval var g = false) then 
					evalexpression ( Sum ( simplifierSYGMA var max f ia	witheps exprea,
										  evalexpression (Prod (Sum(max,ConstInt("1")) , g))
										 ))
				else
				begin
					evalexpression ( Sum  ( simplifierSYGMA var max f ia witheps exprea,  simplifierSYGMA var max g ia	witheps exprea))

				end
			end
		| Diff (f, g) 	->  
			if (estVarDsExpEval var f = false) then
			begin 
				if (estVarDsExpEval var g = false) then  
					evalexpression (Prod (Sum(max,ConstInt("1")), expre))
				else 
					evalexpression ( Diff 
										( evalexpression (Prod (Sum(max,ConstInt("1")), f)),
										  simplifierSYGMA var max g ia	witheps exprea))
			end
			else 
			begin
				if (estVarDsExpEval var g = false) then 
					evalexpression ( Diff ( simplifierSYGMA var max f ia	witheps exprea,
										  evalexpression (Prod (Sum(max,ConstInt("1")), g))
										 ))
				else
					evalexpression ( Diff  ( simplifierSYGMA var max f ia witheps exprea,  simplifierSYGMA var max g ia	witheps exprea))
			end
	
		| Prod (f, g)  | Shr (f, g) ->  
				if (estVarDsExpEval var f = false) then (* f constante*) 
				begin
					 if (estVarDsExpEval var g = false) then 
						evalexpression(Prod (Sum(max,ConstInt("1")), expre))
					 else
					 begin 
						(*Printf.printf "pas dans f mais dans g\n";
						 print_expTerm (evalexpression f);  new_line ();Printf.printf " * ";
 print_expTerm (simplifierSYGMA var max g ia);  new_line ();Printf.printf " \n\n ";*)
						evalexpression(Prod ( f, simplifierSYGMA var max g ia witheps exprea))
					 end
				end
				else
				 	if (estVarDsExpEval var g = false) then 
					begin
						if expre =  Prod (f, g) then evalexpression(Prod ( simplifierSYGMA var max f ia witheps exprea, g))
						else  evalexpression(Shr ( simplifierSYGMA var max f ia witheps exprea, g))
					end 
					else 
					begin
                        if ((sensVariation var max  f ia = CROISSANT) && (sensVariation var max g ia = CROISSANT) )
						|| ((sensVariation var max f ia = DECROISSANT) && (sensVariation var max g ia =DECROISSANT))then
						begin
							let maximum = simplifierMax var max expre ia  witheps exprea in
							if (estNoComp maximum) || estNul maximum then begin (*Printf.printf "NOCOMP2\n";*)NOCOMP end
							else  evalexpression (Prod (Sum(max,ConstInt("1")), maximum))
						end
						else NOCOMP
					end
		 	
			|  Mod (f, g)	->  
				if (estVarDsExpEval var g = false) then 
					if (estVarDsExpEval var f = false) then evalexpression(Prod (Sum(max,ConstInt("1")), expre))
					else evalexpression(Mod (simplifierSYGMA var max f ia witheps exprea, g))
				else  NOCOMP
			| Quot (f, g)	|  Shl (f, g)->  
				if (estVarDsExpEval var g = false) then 
				begin
					if (estVarDsExpEval var f = false) then  evalexpression(Prod (Sum(max,ConstInt("1")), expre))
					else	
					begin
						let res = simplifierSYGMA var max f ia witheps exprea in
						if expre = Quot (f, g) 	then	evalexpression(Quot (res , g))
						else evalexpression(Shl (res , g))
					end
				end
				else if (estVarDsExpEval var f = false) then 	
					begin
						(* je ne sais simplifier que si g est de la forme  cte puiss var *)
						let valg = evalexpression g in
						(match valg with
							Puis(e,vare) ->if (estVarDsExpEval var e = false) then
										   begin
											let res = simplifierSYGMA var max (Puis(Quot(ConstInt("1"), e), vare)) ia witheps exprea in
											evalexpression(Quot (f, res) )
										  end
										 else NOCOMP
							| _-> NOCOMP
						)
					end
					else NOCOMP
		|  Puis (f, g)	->  
				if (estVarDsExpEval var g = false) then 
				begin
					if (estVarDsExpEval var f = false) then  evalexpression(Prod (Sum(max,ConstInt("1")), expre))
					else NOCOMP
				end
				else 
				begin
					if (estVarDsExpEval var f = false) then 
					begin
						if (estAffine var g)   then 
						begin 
							let (a,b) = calculaetbAffineForne var g in		
							let (var1, var2) = (evalexpression a , evalexpression b) in
							let resaux = evalexpression f in
							let maxPlusun = evalexpression (Sum(max,ConstInt("1"))) in
							if (estNul var1) ||( estNul (Diff(resaux, ConstInt("1")))) then maxPlusun
							else if  (estStricPositif var1) then 
								 begin 
									let q = evalexpression( Puis(f, var1)) in
									let unMoinsq = evalexpression( Diff (ConstInt("1"), q) ) in
									let unMoinqPuisitPlusun = evalexpression(Diff(ConstInt("1"), Puis(q, maxPlusun))) in
									evalexpression(Prod(Puis(f,var2), Quot(unMoinqPuisitPlusun, unMoinsq)))
								 end
								 else 
								 begin
									let q = evalexpression( Puis(f, Diff(ConstInt("0"),var1))) in
									let unMoinsq = evalexpression( Diff (ConstInt("1"), q) ) in
									let unMoinqPuisitPlusun = evalexpression(Diff(ConstInt("1"), Puis(q, maxPlusun))) in
									evalexpression(Prod(Puis(f,var2), Quot(unMoinqPuisitPlusun, unMoinsq)))
								 end
						end
						else NOCOMP
					end
					else NOCOMP
				end
		| ConstInt(_) 
		| ConstFloat (_) -> evalexpression (Prod (Sum(max,ConstInt("1")), expre))
		| RConstFloat (_) -> evalexpression (Prod (Sum(max,ConstInt("1")), expre))
		| Boolean (_)-> NOCOMP
		| Var (v) -> if v = var then evalexpression (Sygma (var , ConstInt("0"), max, Var (v)) )
					 else  evalexpression (Prod (Sum(max,ConstInt("1")), expre))
		| PartieEntiereSup (e) ->  evalexpression	(PartieEntiereSup(simplifierSYGMA var max e ia witheps exprea))
		| PartieEntiereInf (e)->  evalexpression	(PartieEntiereInf(simplifierSYGMA var max e ia witheps exprea))
		| Log (e)->  evalexpression	(Log(simplifierSYGMA var max e ia witheps exprea))
   	    | Sygma(v,inf,sup,e)-> evalexpression(Sygma (v,inf,simplifierSYGMA var max sup ia witheps exprea,simplifierSYGMA var max e ia witheps exprea))
		| Max (v,inf,sup,e)->  evalexpression(Max (v,inf,simplifierSYGMA var max sup ia witheps exprea,simplifierSYGMA var max e ia witheps exprea))
		| Eq1 (v)->  Eq1 (v)		
		|  Maximum (f, g)  ->  
			if (estVarDsExpEval var f = false) then
				if (estVarDsExpEval var g = false) then 
					evalexpression  (Maximum (evalexpression f, evalexpression g)) 
				else evalexpression  (Maximum (evalexpression f, simplifierSYGMA var max g ia witheps exprea)) 
			else if (estVarDsExpEval var g = false) then 
					evalexpression  (Maximum (simplifierSYGMA var max f ia witheps exprea, evalexpression g)) 
				else NOCOMP
		|  Minimum (f, g)  ->  
			if (estVarDsExpEval var f = false) then
				if (estVarDsExpEval var g = false) then 
					evalexpression  (Minimum (evalexpression f, evalexpression g)) 
				else evalexpression  (Minimum (evalexpression f, simplifierSYGMA var max g ia witheps exprea)) 
			else if (estVarDsExpEval var g = false) then 
					evalexpression  (Minimum (simplifierSYGMA var max f ia witheps exprea, evalexpression g)) 
				else NOCOMP
) in
if  estDefExp res && getDefValue res <= 0.0 then NOCOMP else res
	
and evalProd var max expre ia witheps exprea=
	let val1 = evalexpression max in
	let val2 = evalexpression expre in
	(*Printf.printf "produit\n";
	print_expTerm val1; new_line ();Printf.printf"\n";
	print_expTerm  val2; new_line ();Printf.printf"\n";
	Printf.printf "produit\n";*)
	if (estNoComp val1) || (estNoComp val2 ) then begin (*Printf.printf "NOCOMP\n";*)NOCOMP end
	else 
	begin
		let res = simplifierSYGMA var val1 val2 ia witheps exprea in
		if estNoComp res (*|| (estDefExp res && getDefValue res <= 0.0 )*) then
			if (estCroissantOuCte var val1 val2 ia) || (estDecroissantOuCte var val1 val2 ia) then
			begin  
				let maximum = simplifierMax var max expre ia witheps exprea in
				if (estNoComp maximum) || estNul maximum then begin (*Printf.printf "NOCOMP2\n";*) NOCOMP end
				else  evalexpression (Prod (Sum(max,ConstInt("1")), maximum))
			end
			else NOCOMP
		else res
	end

and invaq1 v = if v = ConstInt("0") then ConstInt("1") else if v = ConstInt("1") then ConstInt("0") else invaq1 v 

and simplifieraa var max expre ia witheps exprea =
	if !vDEBUG then 
	begin  
		Printf.printf "SYGMA simplifier avant affine\n";
		print_expTerm max; new_line ();Printf.printf"\n";
		print_expTerm expre; new_line ();Printf.printf"\n";
	end;
	if !vDEBUG then Printf.printf"SYGMA simplifier dans simplifier\n"; 
if estDefExp max = false then NOCOMP
else
if estNul max then  calculer  (EXP (expressionEvalueeToExpression  (remplacerVpM  var (ConstInt("0")) exprea) ))  !infoaffichNull  [] 1
else
begin
    if (ia = NONMONOTONE) then   NOCOMP
	else
	begin		
		if ((estAffine var expre) && (estVarDsExpEval var max = false))  then 
		begin 
			(*Printf.printf"SYGMA simplifier dans simplifier affine\n"; *)
			let borneMaxSupposee = calculer  (EXP (expressionEvalueeToExpression   (remplacerVpM  var max exprea)))  !infoaffichNull  [] 1 in
			let borneInfSupposee = calculer  (EXP (expressionEvalueeToExpression   (remplacerVpM  var (ConstInt("0")) exprea)))  !infoaffichNull  [] 1 in

	(*begin
					Printf.printf"S simplifier non affine max expre max suppose min suppose %s\n" var; 
					print_expTerm max; new_line ();Printf.printf"\n"; 
					print_expTerm exprea; new_line ();Printf.printf"\n"; 
					print_expTerm borneMaxSupposee; new_line ();Printf.printf"\n"; 
					print_expTerm borneInfSupposee; new_line ();Printf.printf"\n"; 
 

				end;*)
		if  estDefExp borneMaxSupposee && estDefExp borneInfSupposee then
		begin
			(*Printf.printf "bornes definies simplifier aa \n";*)
			let sensVariReel  =
			(	if estPositif borneMaxSupposee && estPositif borneInfSupposee then
				 	estPositif 
					( evalexpression (Diff( evalexpression borneMaxSupposee, borneInfSupposee))) 
				else if estPositif borneMaxSupposee && (estPositif borneInfSupposee =false) then
					 true
					 else 
						if (estPositif borneMaxSupposee =false) && (estPositif borneInfSupposee )
						then false
						else 
						estPositif ( evalexpression 
						(Diff( evalexpression borneMaxSupposee, borneInfSupposee))) = false
			) in

			if (estPositif borneMaxSupposee = false) && (estPositif borneInfSupposee =false) then  
			begin
				(*Printf.printf "pas dans la boucle\n";		*)
				ConstInt("0")
			end
			else
			begin
				let (a,b) = calculaetbAffineForne var expre in		
				let (var1, var2) = (evalexpression a , evalexpression b) in
				let convFloat =  ( match var1 with  ConstInt(j) -> ConstFloat(j) |_-> var1) in
				let mbSura = 
					(if convFloat = ConstFloat("0")|| convFloat = RConstFloat(0.0)then ConstFloat("0")
					 else  evalexpression (Quot ( Diff	 ( ConstInt("0"),var2 )  , convFloat)))in
						(*-b/a*)
				let mbSuraInf = evalexpression 
							(PartieEntiereSup ( evalexpression (Diff (mbSura,ConstInt("1"))))) in
				let mbSuraSup = evalexpression 
							(PartieEntiereInf ( evalexpression (Sum  (mbSura,ConstInt("1"))))) in
				

			if  (estDefExp var1 && estDefExp var2) then
			begin
				if  (estPositif var1) then (* revoir ce test pour resludcmp.c*)   
				begin
					if  (sensVariReel = true) then
					begin
						(*Printf.printf"positif croissant\n";*)
						let maxMoinsMbSura=evalexpression (Diff( evalexpression max, mbSuraInf)) in
						if (getDefValue maxMoinsMbSura >0.0) then
						begin (*Printf.printf"positif croissant\n";*)
							let maximum = maxi mbSuraInf  (ConstInt("0"))  in
							if (estNul maximum ) then 
								calculer  (EXP (expressionEvalueeToExpression  (remplacerVpM var max exprea) ))  !infoaffichNull  [] 1
								 
							else  calculer  (EXP (expressionEvalueeToExpression
								(Diff  ( calculer  (EXP (expressionEvalueeToExpression  (remplacerVpM var max exprea) ))  !infoaffichNull  [] 1,  
								remplacerVpM var
									(evalexpression (Diff (mbSuraInf,ConstInt("1")))) exprea) )))  !infoaffichNull  [] 1
						end
						else  begin Printf.printf"CAS1\n";ConstInt("0")  end
					end
					else	(* decr*)
					begin
						(*Printf.printf"positif decroissant\n";*)
						let maxMoinsMbSura =evalexpression(Diff( evalexpression max, mbSuraSup)) in
						if (estPositif maxMoinsMbSura) then
						begin 
							let maximum = maxi mbSuraSup  (ConstInt("0"))  in
							if estNul maximum  then 
							begin
							(*	Printf.printf "decroissant max = 0 maxMoinsMbSura >0\n";	*)	


								calculer  (EXP (expressionEvalueeToExpression  (remplacerVpM var max exprea)))!infoaffichNull  [] 1
							end
							else
							begin
								(*Printf.printf "decroissant max > 0maxMoinsMbSura >0\n"; *)





								calculer  (EXP (expressionEvalueeToExpression  (Diff 
									( calculer  (EXP (expressionEvalueeToExpression  (remplacerVpM var max exprea) ))  !infoaffichNull  [] 1,  
									 remplacerVpM  var  
									(evalexpression (Diff (mbSuraSup,ConstInt("1")))) exprea) )))  !infoaffichNull  [] 1
							end
						end
						else   begin Printf.printf"CAS2\n";ConstInt("0")  end
					end (*end decr*)
				end
				else (* var1 neg*)
				begin
					if  (sensVariReel = true) then
					begin (*Printf.printf"negatif croissant\n";*)
						if getDefValue mbSuraSup > 0.0 then 
							calculer  (EXP (expressionEvalueeToExpression (remplacerVpM var (mini mbSuraSup  max) exprea) ))  !infoaffichNull  [] 1
						else  begin Printf.printf "CAS6\n"; ConstInt("0")  	end
					end
					else		
					begin	(*Printf.printf"negatif decroissant\n";*)
						if getDefValue mbSuraInf <  0.0 then   ConstInt("0")
							(*calculer  (EXP (expressionEvalueeToExpression (remplacerVpM var (ConstInt("0")) exprea) ))  !infoaffichNull  [] 1*)
						else  
						begin (*Printf.printf "CAS7\n";*) (*ConstInt("0")*) 
								



								let maximum = (*Quot ( ConstFloat("1.0")  ,  Diff	 ( ConstInt("0"),var1 ))*)( ConstInt("0")) in
								calculer  (EXP (expressionEvalueeToExpression (remplacerVpM var   maximum exprea) ))  !infoaffichNull  [] 1			
						end	
					end
				end
			end else  ((*Printf.printf"X\n";*)NOCOMP)
			end
			end (*estDef*)
			else   ((*Printf.printf"Y\n";*)NOCOMP)
		end (*fin affine*)
		else (*non affine*)
		begin
			if  ((estVarDsExpEval var expre = false) && (estVarDsExpEval var max) )then 
 
				calculer  (EXP (expressionEvalueeToExpression (Prod (expre,Sum(max, ConstInt("1"))))))!infoaffichNull  [] 1
			else 
			begin 
				if !vDEBUG then Printf.printf"SYGMA simplifier non affine !!!\n"; 
			(*	 traiterGeometrique var expre max ia *) 
				evalProd var max expre ia witheps exprea
			end
		end
	end
end

and simplifier var max expre ia witheps exprea =
let simpli = simplifieraa var max expre ia witheps exprea in

let prodeng = evalProd var max expre ia witheps exprea in
if estNoComp simpli  && estNoComp prodeng  then 
begin
	if  estPositif (evalexpression (Diff( prodeng, simpli))) then simpli else  prodeng
end
else simpli
(*simpli*)

and simplifierMax var max expre ia witheps exprea=
	if !vDEBUG then 
	begin  
		Printf.printf "Max simplifier avant affine var %s \n" var;
		print_expTerm max; new_line ();
		print_expTerm expre; new_line ();
		print_expTerm exprea; new_line ();
	end;

if ((estVarDsExpEval var expre = false) && (estVarDsExpEval var max = false))  then expre
else
begin
  if (ia = NONMONOTONE) then NOCOMP
  else
  begin		
	if ((estAffine var expre) && (estVarDsExpEval var max = false))  then 
	begin 
		(*Printf.printf"MAX simplifier dans simplifier affine\n"; *)
		let borneMaxSupposee = calculer  (EXP (expressionEvalueeToExpression  (remplacerVpM  var max expre)))  !infoaffichNull  [] 1 in
		let borneInfSupposee = calculer  (EXP (expressionEvalueeToExpression  (remplacerVpM  var (ConstInt("0")) expre))) !infoaffichNull  [] 1 in

		let borneMaxSupposee1 = calculer  (EXP (expressionEvalueeToExpression  (remplacerVpM  var max exprea)))  !infoaffichNull  [] 1 in
		let borneInfSupposee1 = calculer  (EXP (expressionEvalueeToExpression  (remplacerVpM  var (ConstInt("0")) exprea))) !infoaffichNull  [] 1 in

	(*begin
					Printf.printf"MAX simplifier non affine max expre max suppose min suppose\n"; 
					print_expTerm max; new_line ();Printf.printf"\n"; 
					print_expTerm expre; new_line ();Printf.printf"\n"; 
					print_expTerm borneMaxSupposee; new_line ();Printf.printf"\n"; 
					print_expTerm borneInfSupposee; new_line ();Printf.printf"\n"; 
print_expTerm borneMaxSupposee1; new_line ();Printf.printf"\n"; 
					print_expTerm borneInfSupposee1; new_line ();Printf.printf"\n"; 

				end;*)



	if  estDefExp borneMaxSupposee && estDefExp borneInfSupposee then
	begin
		let sensVariReel  =
		  (if estPositif borneMaxSupposee && estPositif borneInfSupposee then
		  	estPositif (evalexpression (Diff( evalexpression borneMaxSupposee, borneInfSupposee))) 
			else 
				if estPositif borneMaxSupposee && (estPositif borneInfSupposee =false) then true
			 	else 
					if (estPositif borneMaxSupposee =false) && (estPositif borneInfSupposee)
					then false
					else 
						estPositif ( evalexpression (Diff( evalexpression borneMaxSupposee, borneInfSupposee))) = false
			) in

		if (estPositif borneMaxSupposee1 = false) && (estPositif borneInfSupposee1 =false) then 
		begin
			(*Printf.printf"MAXCAS1\n";*)
			if estDefExp borneMaxSupposee1 = true then 	ConstInt("0") else NOCOMP
		end
		else
		begin
			let (a,b) = calculaetbAffineForne var expre in		
			let var1 = evalexpression a in
			let var2 = evalexpression b in
			let convFloat =  ( match var1 with  ConstInt(j) -> ConstFloat(j) |_-> var1) in
			let mbSura =(if convFloat = ConstFloat("0") || convFloat = ConstFloat("0.0") ||convFloat = RConstFloat(0.0) then ConstFloat("0")
						else  evalexpression (Quot ( Diff( ConstInt("0"),var2 ), convFloat)))in	
	(*-b/a*)

			let mbSuraInf =  evalexpression (PartieEntiereSup ( evalexpression (Diff (mbSura,ConstInt("1"))))) in
			let mbSuraSup =  evalexpression (PartieEntiereInf ( evalexpression (Sum (mbSura,ConstInt("1"))))) in	

			let bmaximum = 
					(
						if  (estDefExp var1 && estDefExp var2) then
						begin
							if estNul a then borneInfSupposee1
							else
									if  (estPositif var1)  then 
									begin
										if (sensVariReel = true ) then
										begin
											(*Printf.printf "a positif croissant\n";*)
											let maxMoinsMbSura=evalexpression(Diff( evalexpression max, mbSuraInf)) in
											if estDefExp maxMoinsMbSura then
												if  getDefValue maxMoinsMbSura > 0.0 then
												begin (*Printf.printf"eval2\n";*)
													let res =
													calculer  (EXP (expressionEvalueeToExpression  (remplacerVal var max exprea) )) !infoaffichNull  [] 1 in
												(*	print_expTerm res; new_line ();Printf.printf"\n"; *)
													res
												end
												else  begin (*Printf.printf"MAXCAS2\n";  *)ConstInt("0")  end
											else NOCOMP
										end
										else
										begin
											(*Printf.printf "a positif decroissant\n";*)
											let maxMoinsMbSura=evalexpression (Diff( evalexpression max, mbSuraSup)) in
											if estDefExp maxMoinsMbSura then
												if estPositif maxMoinsMbSura then
												begin
													(*Printf.printf "cas 2 decroissant \n";*)
													let maximum = maxi mbSuraSup  (ConstInt("0"))  in
													if estNul maximum   then 
													begin (*Printf.printf"eval3\n";*)
														calculer  (EXP (expressionEvalueeToExpression  (remplacerVal var (ConstInt("0")) exprea) )) 
														!infoaffichNull  [] 1
													end
													else  
													begin (*Printf.printf"eval4\n";*)
														calculer  (EXP (expressionEvalueeToExpression  ( remplacerVal  var  mbSuraSup exprea)  )) 
																		!infoaffichNull  [] 1
													end
												end
												else  begin  (*Printf.printf"MAXCAS3\n"; *)ConstInt("0") end  
											else NOCOMP
										end
				
									end
									else 
									begin
										if (sensVariReel = true )then
										begin
											if estDefExp mbSuraSup then
												if  getDefValue mbSuraInf > 0.0  then 
												begin
													(*Printf.printf"eval5\n";*)
													 
													calculer  (EXP (expressionEvalueeToExpression  (remplacerVal var (ConstInt("0")) exprea) )) 
													!infoaffichNull  [] 1
												end
												else begin  (*Printf.printf"MAXCAS4\n";*) ConstInt("0") end  
											else NOCOMP	
										end
										else
										begin		
											if estDefExp mbSuraInf then	
												if getDefValue mbSuraInf <= 0.0 then (*revoir*)
												begin
													(*Printf.printf"eval6\n";*)ConstInt("0")
													 (*calculer  (EXP (expressionEvalueeToExpression  (remplacerVal var (ConstInt("0")) exprea) ))
!infoaffichNull  [] 1 *)
												
												end
												else begin (* Printf.printf "cas 4\n";*) (* ConstInt("0")*)
													 let maximum = (*Quot ( ConstFloat("1.0")  ,  Diff	 ( ConstInt("0"),var1 ))*)( ConstInt("0"))in
 													calculer  (EXP (expressionEvalueeToExpression  (remplacerVal var maximum exprea) )) 
													!infoaffichNull  [] 1						end	
											else NOCOMP
										end						
									end
							end else NOCOMP
						) in
				(*Printf.printf "maximum5\n" ; print_expTerm bmaximum; new_line (); Printf.printf "maximum\n";*)
		if estDefExp bmaximum  then if estPositif bmaximum then bmaximum else  begin (* Printf.printf"MAXCAS5\n";*) ConstInt("0") end 
		else NOCOMP
	end
end (*estDef*)
			else NOCOMP
	end
	else
	begin
		if  ((estVarDsExpEval var expre = false) && (estVarDsExpEval var max) )then 
		begin 
			if !vDEBUG then Printf.printf"MAX simplifier borne depend\n";
				calculer  (EXP (expressionEvalueeToExpression  (exprea))) !infoaffichNull  [] 1
		end
		else 
		begin 
			let sens = sensVariation var max  expre ia in
			(*printSens sens;*)
			if sens <> NONMONOTONE then
			begin
				(*traiterGeometrique var expre max ia *)
				let borneMaxSupposee = calculer  (EXP (expressionEvalueeToExpression  (remplacerVal  var max exprea) )) !infoaffichNull  [] 1 in
				let borneInfSupposee = calculer  (EXP (expressionEvalueeToExpression  (remplacerVal  var (ConstInt("0")) exprea) )) !infoaffichNull  [] 1 in
					
				(*if estMONOTONBE var max expr then*)
				if !vDEBUG then 
				begin
					Printf.printf"MAX simplifier non affine max expre max suppose min suppose\n"; 
					print_expTerm max; new_line ();Printf.printf"\n"; 
					print_expTerm expre; new_line ();Printf.printf"\n"; 
					print_expTerm borneMaxSupposee; new_line ();Printf.printf"\n"; 
					print_expTerm borneInfSupposee; new_line ();Printf.printf"\n"; 
				end;
				let maximum = maxi borneMaxSupposee  borneInfSupposee  in
	(*Printf.printf"maximum6\n"; *)
	(*print_expTerm maximum; new_line ();Printf.printf"\n"; *)
				if estDefExp maximum  then 
					if estPositif maximum  then maximum  else begin (* Printf.printf"MAXCAS6\n"; *) ConstInt("0") end
				else NOCOMP 
				end
				else begin (*Printf.printf "non monotone\n";*) NOCOMP end
			end
		end
	end
end

let geometrique exp expvarB = 
BINARY(	DIV ,
		BINARY(	SUB,CONSTANT(CONST_INT("1")) , 
			CALL (VARIABLE("pow"),List.append	
				[exp] 
				[CALL (	VARIABLE("MAXIMUM") ,  List.append 
					  [CONSTANT(CONST_INT("0"))] [BINARY(ADD, VARIABLE expvarB, CONSTANT(CONST_INT("1")) )])
				] )),
		BINARY(SUB ,CONSTANT(CONST_INT("1")) , exp)
	)



type typeListeAS = abstractStore list
type assos = string * abstractStore list
let new_assos id asL = (id,asL)

let listeASCourant = ref [] 	
let listeDesVarDependITitcour = ref [] (* as changed durind fixed point operator*)





let  (globalesVar:string list ref) = ref[]
let asToListeAffect a =
match a with
		ASSIGN_SIMPLE (s, e) 	 ->	new_instVar s e 	
	|	ASSIGN_DOUBLE (s,e1, e2) ->	new_instTab s e1 e2
	|	ASSIGN_MEM (id, e1, e2)	->  new_instMem id e1 e2


let rec listeAsToListeAffect l =
if l = [] then [] else List.append [asToListeAffect (List.hd l)] (listeAsToListeAffect (List.tl l))
						


let rec afficherLesAffectations listeAffect = List.iter (fun affect -> afficherUneAffect affect; flush();flush(); space(); new_line ()) listeAffect
and afficherUneAffect affect =
	Printf.printf "\t\t\t\t\t";
	match affect with
	 VAR ( id, expVA1) 				->	 Printf.printf "%s  <- " id ;  flush (); print_expVA expVA1; flush(); space();
	|  MEMASSIGN ( id, expVA1, expVA2)	->	 Printf.printf "%s  <- (" id ; flush (); print_expVA expVA1; flush(); space();
																 Printf.printf " ) <- ";flush(); space(); 
											 flush (); print_expVA expVA2; flush(); space();
	| TAB ( id, expVA1, expVA2) 	->   Printf.printf "%s  [" id ; flush (); print_expVA expVA1; flush(); space();
										 Printf.printf " ] <- "; print_expVA expVA2; 	flush(); space();
	| IFVF ( expVA1, i1, i2) 		->
			Printf.printf  "if (";	print_expVA expVA1;flush(); space(); Printf.printf  ")"; new_line (); 
			Printf.printf "{";		indent (); afficherUneAffect i1;flush(); space(); new_line (); unindent ();
			Printf.printf "}";new_line ();
			Printf.printf  "else "; 
			Printf.printf "{";		indent (); afficherUneAffect i2; flush(); space();	unindent ();
			Printf.printf "}"; new_line ()
	| IFV ( expVA1, i1) 		->
			Printf.printf  "if (";	print_expVA expVA1; flush(); space();Printf.printf  ")"; new_line (); 
			Printf.printf "{";		indent (); afficherUneAffect i1; unindent ();
			Printf.printf "}"; new_line ()
	| BEGIN (liste)			->  afficherLesAffectations liste; new_line ()	;	flush(); space();			
	| FORV ( num, id, expVA1, expVA2, expVA3, _, i) -> 	
			Printf.printf "num loop %d\n" num; Printf.printf "/* %s" id ; flush();Printf.printf " */\nfor ("; flush(); space();
			new_line ();  print_expVA expVA1;flush(); space(); Printf.printf "; ";	print_expVA expVA2; flush(); space();Printf.printf "; " ;
			print_expVA expVA3;  new_line () ; Printf.printf ")\n" ;
			Printf.printf "{";		indent (); afficherUneAffect i; flush(); space(); unindent ();
			Printf.printf "}"; new_line ()
	| APPEL (num, avant, nom, apres,CORPS c,_,_) ->
			Printf.printf  "\n\t\t\t\tFUNCTION CALL INPUT APPEL numbero %d %s \n" num nom; 
			afficherUneAffect avant;new_line () ;
			Printf.printf  "\n\t\t\t\tFUNCTION CORPS(VRAI CORPS) APPEL numbero %d\n" num; 
			afficherUneAffect c;new_line () ; 
			Printf.printf  "\t\t\t\t NAME %s\n" nom; 
			Printf.printf  "\t\t\t\t FUNCTION CALL OUTPUT\n"; 
			afficherUneAffect apres;new_line () ;flush(); space();
Printf.printf  "\t\t\t\t FIN  OUTPUT %d %s\n" num nom;  
	| APPEL (num, avant, nom, apres,ABSSTORE a,_,_) ->
			Printf.printf  "\n\t\t\t\tFUNCTION CALL INPUT APPEL numbero %d %s \n" num nom; 
			afficherUneAffect avant;new_line () ;
			Printf.printf  "\n\t\t\t\tFUNCTION CORPS(ABSTRACT STORE) APPEL numbero %d\n" num; 
			 afficherListeAS a ; print_string "PAS AFFICHE" ;new_line () ; 
			Printf.printf  "\t\t\t\t NAME %s\n" nom; 
			Printf.printf  "\t\t\t\t FUNCTION CALL OUTPUT\n"; 
			afficherUneAffect apres;new_line () ;flush(); space();
Printf.printf  "\t\t\t\t FIN  OUTPUT %d %s\n" num nom;  
Printf.printf  "\n\t\t\t\tFUNCTION CALL INPUT APPEL numbero %d %s FIN \n" num nom




let rec getCondIntoList ifid listeAffect = 
if listeAffect = [] then (false, EXP(NOTHING))
else
begin
	let (trouve, exp) = getCond ifid (List.hd listeAffect) in
	if trouve then (trouve, exp) else getCondIntoList ifid  (List.tl listeAffect) 
end


and getCond ifid affect =
	match affect with
	 VAR ( id, expVA1) 				->	 if id = ifid then (true, expVA1) else  (false, EXP(NOTHING))
	|  MEMASSIGN ( _, _, _)	| TAB  ( _, _, _)	->	 (false, EXP(NOTHING))
									
	| IFVF (_, i1, i2) 		->
			let (trouve, exp) = getCond ifid i1 in
			if trouve then  (trouve, exp)  else getCond ifid i2
	| IFV ( _, i1) 		->getCond ifid i1 
	| BEGIN (liste)			-> getCondIntoList ifid liste 		
	| FORV ( _, _,_, _, _, _, i) -> 	getCond ifid i
	| APPEL (_, _, nom, _,CORPS c,_,_) -> if List.mem_assoc  nom !alreadyEvalFunctionAS = false then getCond ifid c else (false, EXP(NOTHING))
	| APPEL (_, _, _, _,ABSSTORE a,_,_) ->(false, EXP(NOTHING))
			 

let afficherListeDesFctAS liste=
if liste <> [] then
begin
	Printf.printf "AFFICHER LISTE DES ASSOS\n";
	List.iter (fun (n,asL)->  new_line ();Printf.printf n;new_line ();afficherListeAS asL;new_line ();new_line ()  ) liste  ;						
	Printf.printf "AFFICHER FIN LISTE DES ASSOS\n"
end

let new_listeAssos  a liste= liste := List.append !liste [a]
	





let rec existAffectVDsListeAS v (*index*) l =
(*Printf.printf "recherche %s dans liste :\n" v;afficherListeAS l;new_line ();Printf.printf "fin s liste :\n" ;*)
if l = [] then false
else 
let a = List.hd l in
let suite = List.tl l in
	match a with
		ASSIGN_SIMPLE (s, e) 	 -> 	if s = v then true else existAffectVDsListeAS v (*index*) suite
	|	ASSIGN_DOUBLE (s,e1, e2) -> 	
			if s = v (*and il faut évaluer les 2 expression index = e1*) then true
			else  existAffectVDsListeAS v (*index*) suite
	| ASSIGN_MEM (id, e1, e2)	-> 
			if id = v (*and il faut évaluer les 2 expression index = e1*) then true
			else  existAffectVDsListeAS v (*index*) suite

let rec rechercheAffectVDsListeAS v (*index*) l =
(*Printf.printf "recherche %s dans liste :\n" v;afficherListeAS l;new_line ();Printf.printf "fin s liste :\n" ;*)
if l = [] then EXP(NOTHING)
else 
let a = List.hd l in
let suite = List.tl l in
	match a with
		ASSIGN_SIMPLE (s, e) 	 -> 	if s = v then e else rechercheAffectVDsListeAS v (*index*) suite
	|	ASSIGN_DOUBLE (s,e1, e2) -> 	
			if s = v (*and il faut évaluer les 2 expression index = e1*) then 
			begin
				if !vDEBUG then begin	Printf.printf "tableau avec index à terminer\n";(* afficherAS a *) end; 
				e2
			end
			else  rechercheAffectVDsListeAS v (*index*) suite
	| ASSIGN_MEM (s, e1, e2)	-> 
			if s = v (*and il faut évaluer les 2 expression index = e1*) then 
			begin
				if !vDEBUG then begin	Printf.printf "tableau avec index à terminer\n";(* afficherAS a *) end; 
				e2
			end
			else  rechercheAffectVDsListeAS v (*index*) suite


let estMultipleDef v (*index*) l = match rechercheAffectVDsListeAS v (*index*) l with MULTIPLE -> true | EXP (e) -> false

let estDef v (*index*) l = match rechercheAffectVDsListeAS v (*index*) l with MULTIPLE -> true | EXP (e) -> if e=NOTHING then false else true

let expressionAffectVar v (*index*) l = match rechercheAffectVDsListeAS v (*index*) l with MULTIPLE -> NOTHING | EXP (e) -> e

let contientAssos liste n = List.exists (fun a ->let (nom, _) = a in nom = n)liste	
let valeurAssos liste n = List.find (fun a ->let (nom, _) = a in nom = n)liste
	
type listeDesVar = string list

let rec rechercheLesVar listeaS listeVAR =
if (listeaS = []) then listeVAR
else 
	begin
		let aSCourant = List.hd listeaS in
		let suite = List.tl listeaS in
		match aSCourant with
		ASSIGN_SIMPLE (id, _) ->if(List.mem id listeVAR) then (rechercheLesVar suite listeVAR)
								else 	List.append (rechercheLesVar suite listeVAR) [id]
		| ASSIGN_DOUBLE (id, _, _) -> 
								if(List.mem id listeVAR) then (rechercheLesVar suite listeVAR)
								else List.append (rechercheLesVar suite listeVAR) [id]	
		| ASSIGN_MEM (id, _, _)	-> 	if(List.mem id listeVAR) then (rechercheLesVar suite listeVAR)
								else List.append (rechercheLesVar suite listeVAR) [id]	
	end
	
let existeAffectationVarListe var liste =
if liste = [] then false else  List.exists (fun aSCourant ->  match aSCourant with ASSIGN_SIMPLE (id, _) |ASSIGN_DOUBLE (id, _, _) |ASSIGN_MEM (id, _, _)->  id = var ) liste  
let existeAffectationVarListeSimple var liste =
if liste = [] then false else  List.exists (fun aSCourant ->  match aSCourant with ASSIGN_SIMPLE (id, _) ->  id = var|ASSIGN_DOUBLE (id, _, _) |ASSIGN_MEM (id, _, _)->false ) liste  
			 
let ro var liste =
   List.find  (fun aSCourant -> match aSCourant with ASSIGN_SIMPLE (id, _)  |ASSIGN_DOUBLE (id, _, _)  |ASSIGN_MEM (id, _, _)-> id = var ) liste

let rofilter var liste =
		List.filter 
		(fun aSCourant ->  match aSCourant with ASSIGN_SIMPLE (id, _) |	ASSIGN_DOUBLE (id, _, _) |ASSIGN_MEM (id, _, _)	->  id = var ) liste
let rofilterandmem var liste =
		List.filter 
		(fun aSCourant ->  match aSCourant with ASSIGN_SIMPLE (id, _) |	ASSIGN_DOUBLE (id, _, _) |ASSIGN_MEM (id, _, _)	->  id = var || id = "*"^var ) liste

let rofiltertabandmemonly var liste =
		List.filter 
		(fun aSCourant ->  match aSCourant with ASSIGN_SIMPLE (id, _) -> false |	ASSIGN_DOUBLE (id, _, _) |ASSIGN_MEM (id, _, _)	->  id = var || id = "*"^var ) liste




let existassigndouvle var liste =
		List.exists 
		(fun aSCourant ->  match aSCourant with  	ASSIGN_DOUBLE (id, _, _)  	->  id = var  |_-> false) liste



let rec roavant  (liste: abstractStore list )
				 ( aS: abstractStore  ) 
				 (resaux : abstractStore list )=
if liste = [] then (resaux, [])
else
begin
	let (head, others) = (List.hd liste,  List.tl liste) in
 	if (aS = head) then  (resaux, others) else (roavant  others aS (List.append resaux [head]) )
end

let listeAffectationVarListe var liste =
 List.filter (fun aSCourant -> match aSCourant with ASSIGN_SIMPLE (id, _) |	ASSIGN_DOUBLE (id, _, _)  |ASSIGN_MEM (id, _, _)->  (id = var) ) liste  
						
let boolAS = ref true

let eqindex i j =
if i = j then begin (*Printf.printf " index egaux \n" ;*) true end else 
begin
	let i1 = calculer i !infoaffichNull [] 1 in
	let ii1 = calculer j !infoaffichNull  [] 1 in
	if estNoComp i1 || estNoComp ii1 then false (*en fait en ne peut pas répondre*)
	else if  estNul (evalexpression (Diff (i1, ii1 ))) then  begin (*Printf.printf " index egaux \n" ;*) true end  else false
end

let diffindex i j  = (*parfois ni diff ni eq on ne sait pas *)
		let i1 = calculer i !infoaffichNull  [] 1 in
		let ii1 = calculer j !infoaffichNull  [] 1 in
		if estNoComp i1 || estNoComp ii1 then false (*en fait on ne peut pas répondre*)
		else if  estNul (evalexpression (Diff (i1, ii1 ))) = false then 
			 begin(* Printf.printf "differents index \n" ;*) true end  
			 else false

let couldBeEqIndex i j  = if (eqindex i j  = true) then true else if (diffindex i j = false) then true else false 

let rofilterWithoutIndex var liste i=
		List.filter 
		(fun aSCourant ->  
			match aSCourant with ASSIGN_SIMPLE (id, _) ->  (id = var)  
			|	ASSIGN_DOUBLE (id, index, _) ->   
					if (id = var) then 
						if couldBeEqIndex i index then false else true
					else false
			|ASSIGN_MEM (id, index, _)	-> 
					if (id = var) then 
						if couldBeEqIndex i index then false else true
					else false
		) liste


let existeAffectationVarIndexListe var l i=
    List.exists (fun aS ->  match aS with ASSIGN_SIMPLE (id, _) ->  false |ASSIGN_DOUBLE (id, index, _) -> (id = var) && eqindex index i|ASSIGN_MEM (id, e, _)	-> 
					eqmemindex id var i e) l

let couldExistAssignVarIndexList var l i=
    List.exists (fun aS ->  match aS with ASSIGN_SIMPLE (id, _)-> (id = var) |ASSIGN_DOUBLE (id, index, _)->(id = var) && couldBeEqIndex index i| ASSIGN_MEM (id, e, _)	-> 
					eqmemindex id var i e) l



let isCallVarStruct lid =
if lid = [] then false
else			let x =  (List.hd lid) in
				if (String.length x> 4) then
				begin
					let var4 = (String.sub x  0 4) in
					if  var4 = "call"   then 
					begin if !vDEBUG then Printf.printf "non traite champ struct depuis appel de fonction";true end else false
				end 
				else false




let isRenameVar = ref false

let getStuctValueOfExpression assign listType=
	let assignedValue = (simplifierValeur assign) in
		match  assignedValue with  
				CONSTANT(	CONST_COMPOUND(expsc))  -> (expsc, true) 
				|  UNARY (op, e) ->
							(match op with
								ADDROF -> (match e with  CONSTANT(	CONST_COMPOUND(expsc)) -> (expsc, true) |_->([], true)  )
								 |_-> ([], true)
									 
							)	
				| VARIABLE(v)->		let rescons = consCommaExp  assignedValue  listType [] []  NOTHING false NOTHING  in
									(match rescons with  CONSTANT(	CONST_COMPOUND(expsc)) -> (expsc, true) |_->([], true)  )
				(*|CALL(VARIABLE "SET", args)->	
									let rescons = consCommaExp  assignedValue  listType [] []  NOTHING  in
									(match rescons with  CONSTANT(	CONST_COMPOUND(expsc)) -> (expsc, true) |_->([], true)  )*)
				|_-> ([], true)
	 
let rec completeType typ =
if typ = [] then []
else List.append [NOTHING] (completeType (List.tl typ))


let rec compareComma exp exp1 res typ=
if exp = [] && exp1 = [] then List.rev res
else if exp = [] || exp1 = [] then List.append (List.rev res) (completeType typ)
	 else  
	 begin
			let (first1, last1,first2, last2,listT) = (List.hd exp, List.tl exp, List.hd exp1, List.tl exp1, if typ = [] then typ else List.tl typ) in
			let lid1 = getInitVarFromStruct ((first1))  in
			let lid2 =	getInitVarFromStruct ((first2))  in

			(*print_expression first1 0;*)
										
			let egal = equalList lid1 lid2 in
			if egal then compareComma last1 last2 (List.append  [first1] res) listT  
			else  compareComma last1 last2 (List.append [NOTHING] res) listT
	 end




let rec simplifierStructSet btype lid listexp e id=
if listexp = [] || List.tl listexp = [] then NOTHING
else
begin  
	let (firstarg,secondarg) = (List.hd listexp, List.hd(List.tl listexp)) in
	let simplifiedfirst =
		match  firstarg with  
				CALL(VARIABLE "SET", args) -> simplifierStructSet btype lid  args e id
			|	CONSTANT(CONST_COMPOUND expsc) ->  getconsCommaExp  btype  lid expsc
			|	_	->remplacerValPar  id  firstarg e in
	let lid1 = getInitVarFromStruct (simplifiedfirst)  in

	let simplifiedsecond =
		match  secondarg with  
				CALL(VARIABLE "SET", args) -> simplifierStructSet btype lid  args e id
			|	CONSTANT(CONST_COMPOUND expsc) ->  getconsCommaExp  btype  lid expsc
			|	_	->remplacerValPar  id  secondarg e in
	let lid2 =	getInitVarFromStruct (simplifiedsecond)  in
	let egal = equalList lid1 lid2 in
			if egal then simplifiedfirst
			else CALL(VARIABLE "SET", List.append [simplifiedfirst] [simplifiedsecond])
end

let rec traiterChampOfstructAux lid valeur id btype e a=
			(	
					let assignedValue = (simplifierValeur valeur) in
					match  assignedValue with  
						CONSTANT cst ->
							(match cst with 
								CONST_COMPOUND expsc -> (*Printf.printf "traiterChampOfstruct MEMBEROFPTR lid non vide  assigncomma%s\n" id;*)
									(*List.iter (fun x-> Printf.printf "%s." x)lid;	Printf.printf "\n";

										print_expression assignedValue 0; new_line() ;*) 
									let na = getconsCommaExp  btype (List.tl lid) expsc in
									(*printfBaseType btype;*)
									(*Printf.printf "new traiterChampOfstruct 1\n";print_expression na 0; new_line() ; *)
									(*if na = VARIABLE ("NOINIT") then assignedValue else*)
									(na)
									|_->  assignedValue
							)
						|  UNARY (op, ex) ->
							(match op with
								ADDROF ->
										(*Printf.printf "traiterChampOfstruct &assign\n";*)
									(match ex with 
										CONSTANT cst ->
											(match cst with
												CONST_COMPOUND expsc ->  
													(*Printf.printf "traiterChampOfstruct MEMBEROFPTR lid non vide  &assigncomma%s\n" id;*)
													(*List.iter (fun x-> Printf.printf "%s." x)lid;	Printf.printf "\n"; *)
													let na = getconsCommaExp  btype (List.tl lid) expsc in
													(*printfBaseType btype;*) (*Printf.printf "new\n";print_expression na 0; new_line() ;  *)
													(*if na = VARIABLE ("NOINIT") then assignedValue else*)
													(*Printf.printf "new traiterChampOfstruct 2\n";print_expression na 0; new_line() ; *)
													(na)
												|_->   remplacerValPar  id  ( UNARY (op, ex)) e 
											)
										|_-> begin (*Printf.printf "traiterChampOfstruct MEMBEROFPTRcas 1 %s\n" id;     *)
										remplacerValPar  id  ( UNARY (op, ex)) e end 
									)
								| MEMOF -> Printf.printf "traiterChampOfstruct *assign id : %s\n" id; 
									let (value,trouve, direct) =   
										if existeAffectationVarListe id a  then 
											(expVaToExp (rechercheAffectVDsListeAS (id) a ), true, true) 
										else 
											if (existeAffectationVarIndexListe ("*"^id) a (EXP(VARIABLE(id)))) then
											begin	
												(*if (existeAffectationVarListe ("*"^v) a ) then *)
												(match (roindex ("*"^id) a (EXP(VARIABLE(id))) ) with 
												ASSIGN_MEM (_,_, EXP(p)) |ASSIGN_DOUBLE (_,_, EXP(p)) |ASSIGN_SIMPLE (_, EXP(p)) -> (p, true ,false) 
														|_   -> (NOTHING, true ,false)  )
											end
											else	if (existeAffectationVarListe ("*"^id) a ) then 
													(expVaToExp (rechercheAffectVDsListeAS ("*"^id) a) , true, false) 
											
												else (e, false, false) in
									if trouve  then
									begin 
										(*	Printf.printf "traiterChampOfstruct *assign id : %s TROUVE\n" id; print_expression value 0; new_line() ; 
											if direct then Printf.printf "  TROUVE direct\n"  else Printf.printf "  TROUVE indirect\n" ; *)
											match value with 
											 CONSTANT cst ->
												(match cst with
													CONST_COMPOUND expsc ->  
												(*		Printf.printf "traiterChampOfstruct MEMBEROFPTR lid non vide  & *assigncomma%s\n" id;*) 
														(*List.iter (fun x-> Printf.printf "%s." x)lid;	Printf.printf "\n"; *)
														let na = getconsCommaExp  btype (List.tl lid) expsc in
														(*if na = VARIABLE ("NOINIT") then assignedValue else*)
														(*printfBaseType btype;*) (*Printf.printf "new\n";print_expression na 0; new_line() ;*)
														(na)
													|_->  if direct then remplacerValPar  id  ( UNARY (op, ex)) e else remplacerValPar  id  value e
												)
											|_-> begin (*Printf.printf "traiterChampOfstruct MEMBEROFPTRcas 1 %s\n" id;   *) 
													remplacerValPar  id  ( UNARY (op, ex)) e end 

									 end
									else remplacerValPar  id  ( UNARY (op, ex)) e
								|_-> begin (*Printf.printf "traiterChampOfstruct MEMBEROFPTR cas 2 %s\n" id;   *)  e end 
							)(*voir autres cas*)
						
						| VARIABLE (varn) ->  if id = varn then e else remplacerValPar  id  (VARIABLE (varn)) e
						| CALL (VARIABLE "SET", args) ->  
								
								let na2 = simplifierStructSet btype (List.tl lid) args e id in
								(*Printf.printf "traiterChampOfstruct MEMBEROFPTR SET %s  expression\n" id ;
								print_expression e 0; new_line() ; new_line() ;flush();space();new_line() ;flush();space(); 
								Printf.printf "traiterChampOfstruct MEMBEROFPTR SET %s  changed set 2\n" id ; print_expression na2 0; new_line() ; ; 
								Printf.printf "traiterChampOfstruct MEMBEROFPTR SET %s  \n" id ;*)
								na2 
						|INDEX(_,_)->	(*Printf.printf "traiterChampOfstruct MEMBEROFPTRcas 3 %s non traité\n" id;*)(* print_expression assignedValue 0;*)
								let (t,i, isOk) =  getArrayAssignFromMem id (EXP(assignedValue)) in

								
								 
								 (* affectation de x(i) dans les deux cas *)
								if isOk && (existeAffectationVarIndexListe t a i) then
								begin
									let  ro2avant = (roindex t a i)  in

									(match  ro2avant with 
									ASSIGN_MEM (_, _, EXP(ee))|ASSIGN_DOUBLE (_, _, EXP(ee)) |ASSIGN_SIMPLE (_,  EXP(ee))-> 
												traiterChampOfstructAux lid  ee id btype e a
									|_-> remplacerValPar  id  assignedValue e)

								 
						 		end
								
 								else remplacerValPar  id  assignedValue e 	
						|_->	(*Printf.printf "traiterChampOfstruct MEMBEROFPTRcas 3 %s non traité\n" id;*)(* print_expression assignedValue 0;*) 								remplacerValPar  id  assignedValue e 				 
				)


let traiterChampOfstruct id a e idsaufetoile lid isptr=

(*		| MEMOF -> ("*", 13)
		| ADDROF -> ("&", 13)*)
(*Printf.printf "traiterChampOfstruct MEMBEROFPTR   id %s sauf* %s\n" id idsaufetoile;print_expression e 0; new_line(); new_line() ;flush();space();*)
let (btype, isdeftype) = 
			if List.mem_assoc idsaufetoile !listAssocIdType then (getBaseType (List.assoc idsaufetoile !listAssocIdType), true) 
			else 
				if List.mem_assoc idsaufetoile !listeAssosPtrNameType then (getBaseType (List.assoc idsaufetoile !listeAssosPtrNameType), true) 
				else (INT_TYPE, false)
in
	if isdeftype then 
	begin			
		 let (hasAssign,gid) =  
			(*	if isptr then	*)
					if (existeAffectationVarListe ("*"^id) a ) then 
						(true, ("*"^id) )
					else if (existeAffectationVarListe id a ) then (true,id) else (false,"") 
				(*else 	if (existeAffectationVarListe id a ) then (true,id) else (false,"") *)
				in
(*if (existeAffectationVarIndexListe x a1 index) then
			begin (* affectation de x(i) dans les deux cas *)
					match  (roindex x a1 index)  with *)

		if hasAssign then 
		begin
			(*Printf.printf "traiterChampOfstruct MEMBEROFPTR   existe \n" ;print_expression e 0; new_line(); new_line() ;flush();space();*)
			let assignedid =  (ro gid a) in
			(match assignedid with 
				ASSIGN_SIMPLE (id, EXP(valeur)) ->  traiterChampOfstructAux lid valeur id btype e a
				| ASSIGN_DOUBLE (id,_,EXP(va)) ->
						(*Printf.printf "traiterChampOfstruct MEMBEROFPTRcas TAB.a %s non traité %s\n" id gid;*) (* boolAS:= true; (NOTHING)*)
								traiterChampOfstructAux lid va id btype e a 
				
				| ASSIGN_MEM (id, index, EXP(va))->traiterChampOfstructAux lid va id btype e a 
				| _->(*Printf.printf "traiterChampOfstruct MEMBEROFPTRcas 4 %s non traité %s\n" id gid; *) boolAS:= true;NOTHING
				(*	if (existeAffectationVarListe idsaufetoile a ) then
					begin
						(*let assignedid =  (ro gid a) in
						if (existeAffectationVarIndexListe x a1 index) then
						begin (* affectation de x(i) dans les deux cas *)
						match  (roindex x a1 index)  with *)
						 
						let index =  (ro idsaufetoile a) in
						(match  index  with ASSIGN_SIMPLE (_, (indexexp)) ->
								if (existeAffectationVarIndexListe gid a indexexp)  then
								begin
									(*Printf.printf "traiterChampOfstruct MEMBEROFPTRTROUVEcas 4 %s non traité %s\n" id gid;*)
									(match  (roindex gid a indexexp)  with 
										ASSIGN_MEM (_,_,EXP(va))|ASSIGN_DOUBLE(_,_, EXP(va))|ASSIGN_SIMPLE(_,EXP(va))-> 
											traiterChampOfstructAux lid va id btype e a 
										|_->boolAS:= true;NOTHING)
								
								 
								end
								else

									begin(*Printf.printf "traiterChampOfstruct MEMBEROFPTRcas 4 %s non traité %s\n" id gid; *) boolAS:= true; (NOTHING)end
					
						|_->(*Printf.printf "traiterChampOfstruct MEMBEROFPTRcas 4.b %s non traité %s\n" id gid;*)  boolAS:= true; (NOTHING))
					end else begin Printf.printf "traiterChampOfstruct MEMBEROFPTRcas 4.a %s non traité %s\n" id gid;  boolAS:= true; (NOTHING)end*)
			)
		end
		else begin(*Printf.printf "AS non exist existeAffectationVarListe\n" ; *)(e)end
	end
	else begin(*Printf.printf "AS non exist \n" ; *)(e)end


let hasSet = ref false


let  unaryToConstConv e isplus=
let unaryTOconst = (*expressionEvalueeToExpression( calculer (EXP(e))  !infoaffichNull [] 1) *) e in
	match e with
		CONSTANT(CONST_INT v)->if isplus then unaryTOconst else
								CONSTANT(CONST_INT( Printf.sprintf "%d" (- (int_of_string  v))))
								 
		| CONSTANT(CONST_FLOAT v)-> if isplus then unaryTOconst else  
				CONSTANT(RCONST_FLOAT(   (-. (float_of_string  v))))
		| CONSTANT(RCONST_INT v1)-> if isplus then unaryTOconst else CONSTANT(RCONST_INT (- v1))
		| CONSTANT(RCONST_FLOAT v1)-> if isplus then unaryTOconst else CONSTANT(RCONST_FLOAT (-. v1))
		| _-> if isplus then e else UNARY (MINUS,e)


 let rec isTrueConstant e=
	match e with
		CONSTANT(CONST_INT v1)| CONSTANT(CONST_FLOAT v1)| CONSTANT(CONST_CHAR v1)|CONSTANT(CONST_STRING v1)->(true,v1)
		| CONSTANT(RCONST_INT v1)->(true,Printf.sprintf "%d"  v1)
		| CONSTANT(RCONST_FLOAT v1)->(true,Printf.sprintf "%f"  v1)
		| UNARY(MINUS,  CONSTANT(CONST_INT v)) -> (true,( Printf.sprintf "%d" (- (int_of_string  v))))
		| UNARY(MINUS,  CONSTANT(CONST_FLOAT v)) -> (true, Printf.sprintf "%f" (-. (float_of_string  v)))
		| UNARY(MINUS,  CONSTANT(RCONST_INT v1)) -> (true,Printf.sprintf "%d"  (- v1))
		| UNARY(MINUS,  CONSTANT(RCONST_FLOAT v1)) -> (true,Printf.sprintf "%f" (-. v1))
		| _->			hasSETCALL := false;
			let val1 = (calculer (EXP(e ))  !infoaffichNull [] 1 ) in 
			if !hasSETCALL = true || estDefExp val1 = false then	 (false,"") else isTrueConstant (expressionEvalueeToExpression val1)

let estTrue myTest =  if  myTest = Boolean(true) then true else false
let estFalse myTest = if  myTest = Boolean(false) then true else false

let rec getIndexValueOfTab val1 expsc =
if expsc = [] then VARIABLE ("--NOINIT--")
else
begin
	let (first, next) = (List.hd expsc, List.tl expsc) in
	if val1 = 0 then first else getIndexValueOfTab (val1 -1) next
end

let rec applyStore e a =
match e with
	NOTHING  -> NOTHING
	| VARIABLE name ->  

		if (existeAffectationVarListe name a ) then 
		begin
			let newassign = (ro name a) in
			
			match newassign with 
				ASSIGN_SIMPLE  (_,EXP(va)) ->isRenameVar := true;  va
				|ASSIGN_SIMPLE  (_,MULTIPLE) ->isRenameVar := true; boolAS:= true;NOTHING
				|_->e

			(*ASSIGN_SIMPLE (_, EXP(valeur)) ->(valeur) |ASSIGN_SIMPLE (_, MULTIPLE) ->isRenameVar := true;boolAS:= true; NOTHING| _ ->	e*)
		end
		else
		begin
			
			if  (String.length name > 19) then
				if (String.sub name 0 19) = "getvarTailleTabMax_" then
				begin	
					let var = String.sub name 19 ((String.length name)-19) in
					if (existeAffectationVarListe var a ) then 
					begin
						
						let newassign = (ro var a) in	
						match newassign with 
							ASSIGN_SIMPLE  (_,EXP(VARIABLE(va))) -> if va != var then begin
							(* Printf.printf " expression applystore getvarTailleTabMax VAR\n"; *)isRenameVar := true;  VARIABLE("getvarTailleTabMax_"^va)
								 end else (e)
							|ASSIGN_SIMPLE  (_,EXP(e)) ->(*Printf.printf " expression applystore getvarTailleTabMax OTHER\n"; *) 
									isRenameVar := true;  CALL(VARIABLE("getvarTailleTabMax_"), [e])
							 |_->e
					end
					else (e)
				end
				else ( e  )

			else ( e  )
		end
	| CONSTANT 	cst	->
		(match cst with 
			CONST_COMPOUND expsc -> (*Printf.printf "consta conpound 1\n"; print_expression e 0; new_line();*)
					let na = CONSTANT( CONST_COMPOUND( List.map (fun arg -> applyStore (arg) a) expsc)) in
					boolAS:= false;
					(*if na != e then begin Printf.printf "new 1\n";print_expression na 0; new_line() end;*)
					(na)
			|_->(*Printf.printf "consta\n";*)(e)	)
		 (*	Printf.printf " expression applystore constante\n";*)
	| UNARY (op, exp1) 				-> 
		(match op with 
				MEMOF -> 
				(
(*Printf.printf"MEMOF\n";
print_expression  (exp1) 0; space();  flush() ; new_line();flush();*)
						let exp1e = applyStore exp1 a in
(*print_expression  (exp1e) 0; space();  flush() ; new_line();flush();*)
						let (tab1,_, _) =getArrayNameOfexp  exp1e  in
						if tab1 != "" then
						begin
							let (indexexp , isok) = consArrayFromPtrExp ( exp1  )  tab1 in
							if  (*isok*) indexexp != NOTHING then 
							begin
								(*let resindex = expressionEvalueeToExpression( calculer  (EXP(applyStore indexexp a))  !infoaffichNull [] 1) in*)
								if existAssosArrayIDsize tab1  then 
								begin
									if (existeAffectationVarIndexListe tab1 a (EXP(indexexp))) then
									begin
										let rotab =roindex tab1 a (EXP(indexexp)) in
										(match rotab with 
										ASSIGN_MEM (_,_,EXP(va))|ASSIGN_DOUBLE(_,_, EXP(va))|ASSIGN_SIMPLE(_,EXP(va))-> va 
										|_->boolAS:= true;NOTHING)
									end
									else 
									begin
										(*print_expression  (INDEX(VARIABLE(tab1), resindex)) 0; space();  flush() ; new_line();flush(); new_line(); flush();Printf.printf"non exist affect\n";*)
										(*let arrayas = arrayAssignFilter tab1 a in
										if arrayas != [] then begin Printf.printf "les as rofilter array\n" ; afficherListeAS arrayas; Printf.printf "fin \n" end ;*)
										INDEX(VARIABLE(tab1), applyStore indexexp a
										)
									end(*UNARY (op, exp1e  )*)	 
								end
								else 
								begin 
										if (existeAffectationVarListe tab1 a ) then 
											(match (ro tab1 a) with ASSIGN_SIMPLE(_,EXP(va))-> UNARY (MEMOF,BINARY(ADD, va, ((applyStore indexexp a))  ))
											|ASSIGN_SIMPLE(_,MULTIPLE)->boolAS:= true;NOTHING|_->UNARY (op, exp1e  ))
										else UNARY (op, exp1e  )  
										(*print_expression  (exp1) 0; space();  flush() ; new_line();flush();*)

										
								end
							end 
							else 
							begin 
								match exp1 with 
									VARIABLE(v) -> 
										if existeAffectationVarListe (v) a then
										begin
											let assignBefore =  (ro v a)  in
											let (before, _) =    roavant a assignBefore  [] in
											if (existeAffectationVarListe ("*"^v) before ) then 
													match (ro ("*"^v) a ) with 
													ASSIGN_MEM (_,_,EXP(va))-> va
													|ASSIGN_MEM (_,_,MULTIPLE)-> boolAS:= true;NOTHING
													|_-> UNARY (op, exp1e  )
											else  UNARY (op, exp1e  )
										end
										else  UNARY (op, exp1e  )
									| UNARY (ADDROF, next) ->  (*Printf.printf "les as rofilter*&\n" ;*)  applyStore next a 
									|_->   (match exp1e with 	 UNARY (ADDROF, next) ->    applyStore next a  
											|_->
												(*if (existeAffectationVarListe tab1 a ) then   UNARY (op,  applyStore exp1e  [ro tab1 a] ) 
												else*) UNARY (op, exp1e  ))
									
							end
						end 
						else 
						begin 
(* Printf.printf "les as rofilter array 2\n" ;*)
							(match exp1 with
							 UNARY (ADDROF, next) ->  (*Printf.printf "les as rofilter*&\n" ;*)  applyStore next a 
							 |_->	(match exp1e with 	 UNARY (ADDROF, next) ->    applyStore next a  |_->  UNARY (op, exp1e  ) ))
						end
					)

			|ADDROF->    	(match exp1 with  UNARY (MEMOF, next) ->    applyStore next a   |_->  
							 UNARY (op, (applyStore exp1 a)))
			|MINUS->unaryToConstConv (applyStore exp1 a) false
			|PLUS-> unaryToConstConv (applyStore exp1 a) true
			|_->  
				UNARY (op, (applyStore exp1 a) )
		)

	| BINARY (op, exp1, exp2) 		-> 	(BINARY (op, (applyStore exp1 a), (applyStore exp2 a)))
	| QUESTION (exp1, exp2, exp3) ->  	
			let evalcond = applyStore exp1 a in
			let rescond = ( calculer  (EXP(evalcond))  !infoaffichNull [] 1) in

			if  (!estDansBoucle = false &&  estTrue rescond )then  applyStore exp2 a
			else 
			begin
				if (!estDansBoucle = false && estFalse rescond )then applyStore exp3 a
				else
				begin
					let valeur1 = (applyStore exp2 a) in
					let valeur2 = (applyStore exp3 a) in

					let (isTruecteArg1, v1) =isTrueConstant valeur1 in
					let (isTruecteArg2, v2) =isTrueConstant valeur2 in
					if isTruecteArg1 then
					begin
						if isTruecteArg2 then
							if v1 = v2 then valeur1
							else  CALL (VARIABLE "SET" , List.append [valeur1] [valeur2])
						else CALL (VARIABLE "SET" , List.append [valeur2] [valeur1])
										 
					end
					else 
					begin
 						if isTruecteArg2 then 	CALL (VARIABLE "SET" , List.append [valeur1] [valeur2])
						else (QUESTION ((evalcond),valeur1,valeur2 ))
					end
				end
			end
			
	| CAST (typ, exp1) 				->	let res = (applyStore exp1 a) in 
										(*if res = NOTHING then  NOTHING  else*) res
	| CALL (exp1, args) 			->	
			(*(match exp1 with		
					VARIABLE("SET")  -> hasSet := false; (* hasSet = has nodef set *)
	Printf.printf "set\n";
								let arg1 =  applyStore (List.hd args) a in
								let hasSetArg1 = !hasSet in
								hasSet := false;
								let arg2 =  applyStore (List.hd (List.tl args)) a in
								let hasSetArg2 = !hasSet in
								if hasSetArg1 && estDefExp arg1 = false ||  hasSetArg2 && estDefExp arg2 = false then hasSet := true else hasSet := false;
								if hasSet then NOTHING else  CALL (  VARIABLE("SET")  , List.append [ arg1] [ arg2] )

					|_->*) CALL (  exp1  , List.map (fun arg -> applyStore arg a) args)
			(* ) *)
	| COMMA exps 					->	(COMMA ( List.map (fun arg -> applyStore (arg) a) exps))
	| EXPR_SIZEOF exp 				->	(EXPR_SIZEOF (applyStore exp a))
	| TYPE_SIZEOF _ 				->	(e)
	| INDEX (exp, idx) 				->	(*Printf.printf " expression applystore index\n";*)
		 let index = (applyStore idx a) in
		(	match exp with
			VARIABLE name ->
				if (existeAffectationVarIndexListe name a (EXP(index)))	then 
				begin
					let absl = roindex  name a (EXP(index))	 in
					(
						match absl with
						ASSIGN_SIMPLE(_,EXP(exp2))|ASSIGN_MEM(_,_,EXP(exp2))|ASSIGN_DOUBLE  (_, _, EXP(exp2))-> (* Printf.printf " trouve =\n";*)
					(*print_expression exp2 0; new_line ();flush(); space();  new_line ();*)exp2 (*je ne suis pas sure d'avoir bien interpete l'algo *)
						| 	_-> INDEX (applyStore exp a, applyStore idx a) 
					)
				end	 
				else	if existeAffectationVarListe name a ||	existeAffectationVarListe ("*"^name) a then
						begin					
								 
								(*afficherListeAS a; *)
								let size = getAssosArrayIDsize name in
								(	match size with 
										NOSIZE ->   boolAS:= true;NOTHING 
										| SARRAY (v) -> 
											let arrayas = arrayAssignFilter name a in
											 
													 
											let (alldedined, min, max) = alldefinedtabMinMax name 0 (v-1) arrayas in
											if alldedined then 
												CALL (	VARIABLE("SET") , 
													List.append [expressionEvalueeToExpression min] [expressionEvalueeToExpression max]
													) 
											else 
											begin  
												INDEX (applyStore exp a, applyStore idx a) 
											end	
											
										| MSARRAY (lsize) -> (*Printf.printf "single tab %s \n" name ;*) 
												INDEX (applyStore exp a, applyStore idx a)
								)
						end
						else (INDEX (exp, index))
			| CONSTANT (CONST_COMPOUND expsc) -> 
					let indexx = (calculer (EXP( index )) !infoaffichNull  [] 1 )in
					let conpound = applyStore exp a in
					
					let res = INDEX (conpound, index) in
					if estDefExp indexx  then  
					begin    

						let val1 = int_of_float(getDefValue indexx) in	

						let geti = (getIndexValueOfTab val1 expsc) in							
						let resaux = applyStore geti a in
						(*print_expression    geti 0;new_line(); flush() ;space(); flush(); new_line(); flush();
						print_expression    resaux 0;new_line(); flush() ;space(); flush(); new_line(); flush();

						afficherListeAS a; space(); flush();new_line();

						Printf.printf "single tab of conpound fin \n"  ;*)
						if resaux = VARIABLE ("--NOINIT--") then res else resaux
						
					end	
					else  res
			
						 
			| _->  
				let (tab1,lidx1) =analyseArray e [] in
				if tab1 != "" then
				begin
					let (indexexp , isok) = consArrayFromPtrExp ( e )  tab1 in
				 				
						if  (*isok = false*) indexexp = NOTHING then  begin INDEX (applyStore exp a, applyStore idx a)  end	
						else
						begin
							 
							begin
								if (existeAffectationVarIndexListe tab1 a  (EXP(indexexp))  ) then
								begin 
									(*let tabvalue = *)
										(match roindex tab1 a  (EXP(indexexp)) with 
											ASSIGN_SIMPLE(_,EXP(va))|ASSIGN_MEM(_,_,EXP(va))|ASSIGN_DOUBLE(_,_, EXP(va)) -> va 
											| 	_->INDEX (applyStore (VARIABLE(tab1)) a, applyStore indexexp a)) (*in*)
									
								end 
								else	
									if existeAffectationVarListe tab1 a ||	existeAffectationVarListe ("*"^tab1) a 	 then
									begin
										 Printf.printf "tab inot trouve but tab existe %s\n" tab1;
										 List.iter (fun i -> print_expression i 0; space();)lidx1;
									 
										(*afficherListeAS a; *)
										let size = getAssosArrayIDsize tab1 in
										(	match size with 
												NOSIZE ->   boolAS:= true;NOTHING 
												| SARRAY (v) -> 
														let arrayas = arrayAssignFilter tab1 a in
														 
															 
														let (alldedined, min, max) = alldefinedtabMinMax tab1 0 (v-1) arrayas in
														if alldedined then 
															CALL (	VARIABLE("SET") , 
																List.append [expressionEvalueeToExpression min] [expressionEvalueeToExpression max]
																	) 
														else 
														begin  
															INDEX (applyStore (VARIABLE(tab1)) a, applyStore indexexp a)
														end	
												| MSARRAY (lsize) -> Printf.printf "single tab %s \n" tab1 ; 
													(*boolAS:= true;NOTHING*)INDEX (applyStore (VARIABLE(tab1)) a, applyStore indexexp a)
										)
									end
									else INDEX (applyStore (VARIABLE(tab1)) a, applyStore indexexp a)
							end
						(*end*)
					end
				end
				else  
				begin 
					 
					INDEX (applyStore exp a, applyStore idx a)
				end 
		)				
	 | MEMBEROF (ex, c) 	->				
				let lid =	getInitVarFromStruct e  in
				if lid != [] && (isCallVarStruct lid = false )then 
				begin
					let fid =  (List.hd lid) in
				    let (id, pid) = if  String.length fid > 1 then 
											if (String.sub fid  0 1)="*" then 
												(String.sub fid 1 ((String.length fid)-1) ,fid) 
											else (fid ,fid )
									else (fid ,fid ) in  
(*print_expression    e 0;new_line(); flush() ;space(); flush(); new_line(); flush();
						 
						Printf.printf "single tab of champ of fin %s %s\n" id pid  ;*)

					let na = traiterChampOfstruct pid a e id lid false in
					if na = VARIABLE ("--NOINIT--") then e else na
			
					
				end
				else ( (*Printf.printf "variable source cas else %s\n"(List.hd lid);*) e )
		
	 | MEMBEROFPTR (ex, c) 		->	(*Printf.printf "applystore MEMBEROFPTR  \n" ;*)
				let lid =	getInitVarFromStruct e  in
				(* *)
				if lid != [] && (isCallVarStruct lid = false )then 
				begin
					let fid =  (List.hd lid) in
				    let (id, pid) = if  String.length fid > 1 then 
											if (String.sub fid  0 1)="*" then 
												(String.sub fid 1 ((String.length fid)-1) ,fid) 
											else (fid ,fid )
									else (fid ,fid ) in 
					(*if id != fid then Printf.printf "id %s, fid %s\n" id pid;*)
				(*	Printf.printf "AS variable source %s\n"(List.hd lid);*)
					let na = traiterChampOfstruct pid a e id lid true in
					if na = VARIABLE ("--NOINIT--") then e else na
			
					
				end
				else ( (*Printf.printf "variable source cas else %s\n"(List.hd lid);*) e )

	| _	-> (*if !vDEBUG then*) Printf.printf "struct et gnu body non traités pour le moment \n"; 
			boolAS:= true; 
			(NOTHING)


and  alldefinedtabMinMax name idmin idmax arrayas = (* (alldedined, min max) *)
let ind = EXP(CONSTANT (CONST_INT (Printf.sprintf "%d" idmin) )) in
if existeAffectationVarIndexListe name arrayas ind then
begin 
		
		let tabvalueExp = (match roindex name arrayas ind with ASSIGN_DOUBLE  (_, _, EXP(exp2))-> exp2  | 	_->NOTHING) in
		if tabvalueExp = NOTHING then (false, NOCOMP, NOCOMP)
		else
		begin
			 let tabvalueEval = (calculer (EXP(tabvalueExp)) !infoaffichNull  [] 1 )in
			 if   estNoComp tabvalueEval   || estDefExp tabvalueEval = false then (false, NOCOMP, NOCOMP)
			 else if idmin = idmax then (true, tabvalueEval,tabvalueEval)
				  else alldefinedtabMinMaxNext name (idmin +1) idmax arrayas tabvalueEval tabvalueEval
		end		
end
else (false, NOCOMP, NOCOMP)


and  alldefinedtabMinMaxNext name idmin idmax arrayas min max = 
let ind = EXP(CONSTANT (CONST_INT (Printf.sprintf "%d" idmin) )) in
if existeAffectationVarIndexListe name arrayas ind then
begin 
		let tabvalueExp = (match roindex name arrayas ind with ASSIGN_DOUBLE  (_, _, EXP(exp2))-> exp2  | 	_->NOTHING) in
		if tabvalueExp = NOTHING then (false, NOCOMP, NOCOMP)
		else
		begin
			 let tabvalueEval = (calculer (EXP(tabvalueExp)) !infoaffichNull  [] 1 )in
			 if   estNoComp tabvalueEval   || estDefExp tabvalueEval = false then (false, NOCOMP, NOCOMP)
			 else if idmin = idmax then (true, mini min tabvalueEval,maxi max tabvalueEval)
				  else alldefinedtabMinMaxNext name (idmin +1) idmax arrayas (mini min tabvalueEval) (maxi max tabvalueEval)
		end
		
end
else (false, min, max)



let rec independantDesVarsDeExpSeules exp asL listeIntersection=
 let (resbool, resliste) = isindependent  listeIntersection asL [] in

(*Printf.printf "independantDesVarsDeExpSeules \n";

Printf.printf "expression\n";print_expression exp 0; new_line() ; new_line() ;flush();space();new_line() ;flush();space();*)
(*Printf.printf "independantDesVarsDeExpSeules \n";
Printf.printf "  independantDesVarsDeExpSeulesAux liste inter \n";List.iter (fun x-> Printf.printf "%s " x)listeIntersection;	Printf.printf "   fin \n";*)
(*if resbool then Printf.printf "resbool true  \n" else  Printf.printf "resbool false  \n";*)




 if resbool then(*afficherListeAS( asL);new_line() ; new_line() ;flush();space();new_line() ;flush();space(); *)
  independantDesVarsDeExpSeulesAux exp asL resliste

 else false



and independantDesVarsDeExpSeulesAux exp asL liste =  (*expression ,abstract store, liste des variables modifiées de l'as*)
	match exp with
		UNARY (_, e) -> 				independantDesVarsDeExpSeulesAux e asL liste
	| BINARY (_, exp1, exp2)| 
		INDEX (exp1, exp2) -> 	 		independantDesVarsDeExpSeulesAux  exp1 asL liste && independantDesVarsDeExpSeulesAux  exp2 asL liste
	| QUESTION (exp1, exp2, exp3) ->	independantDesVarsDeExpSeulesAux  exp1 asL liste && independantDesVarsDeExpSeulesAux  exp2 asL liste && independantDesVarsDeExpSeulesAux  exp3 asL liste
	| CAST (_, e) ->					independantDesVarsDeExpSeulesAux  e asL liste
	| CALL (e, args) ->					independantDesVarsDeExpSeulesAux  e asL liste && independantCommaExpaux args asL liste
	| COMMA e -> 						independantCommaExpaux e asL liste
	| EXPR_SIZEOF e ->					independantDesVarsDeExpSeulesAux  e asL liste
	| MEMBEROF (_, _)->	
			let lid1 =	getInitVarFromStruct exp  in
			if lid1 != [] && (isCallVarStruct lid1 = false )then 
			begin
				let id = (List.hd lid1) in
				if List.mem id liste then
				begin 
						if (existeAffectationVarListe id asL ) then 
						begin
								let na = applyStore exp asL in 
								(*Printf.printf "new\n";print_expression na 0; new_line() ; new_line() ;flush();space();new_line() ;flush();space();*)
									if na = exp || na  = NOTHING then ((*Printf.printf "  independantDesVarsDeExpSeulesAux ok \n";*) true) 
									else 
									begin
									
										let lid2 =	getInitVarFromStruct na  in
										(*Printf.printf "  independantDesVarsDeExpSeulesAux liste1 \n";List.iter (fun x-> Printf.printf "%s." x)lid1;	Printf.printf "\n";
										Printf.printf "  independantDesVarsDeExpSeulesAux liste2 \n";List.iter (fun x-> Printf.printf "%s." x)lid2;	Printf.printf "\n";*)
										let egal = equalList lid1 lid2 in
										if egal then ((*Printf.printf "  independantDesVarsDeExpSeulesAux ok 2 \n";*) true)  else ((*Printf.printf "  independantDesVarsDeExpSeulesAux NOTok \n";*) false)
									end
						end
						else true
				end
				else true
			end
			else false
			

	| MEMBEROFPTR (_, _) ->	
			let lid1 =	getInitVarFromStruct exp  in
			if lid1 != [] && (isCallVarStruct lid1 = false )then 
			begin
				let id = (List.hd lid1) in
				if List.mem id liste then
				begin 
						if (existeAffectationVarListe ("*"^id) asL ) then 
						begin
								let na = applyStore exp asL in 
								(*Printf.printf "new\n";print_expression na 0; new_line() ; new_line() ;flush();space();new_line() ;flush();space();*)
									if na = exp || na  = NOTHING then ((*Printf.printf "  independantDesVarsDeExpSeulesAux ok \n";*) true) 
									else 
									begin
									
										let lid2 =	getInitVarFromStruct na  in
										(*Printf.printf "  independantDesVarsDeExpSeulesAux liste1 \n";List.iter (fun x-> Printf.printf "%s." x)lid1;	Printf.printf "\n";
										Printf.printf "  independantDesVarsDeExpSeulesAux liste2 \n";List.iter (fun x-> Printf.printf "%s." x)lid2;	Printf.printf "\n";*)
										let egal = equalList lid1 lid2 in
										if egal then ((*Printf.printf "  independantDesVarsDeExpSeulesAux ok 2 \n";*) true)  else ((*Printf.printf "  independantDesVarsDeExpSeulesAux NOTok \n";*) false)
									end
						end
						else true
				end
				else true
			end
			else false
			
	| _ -> 						 	true

	 
	
and independantCommaExpaux liste asL dep=
if liste = [] then true 
else   (independantDesVarsDeExpSeulesAux (List.hd liste) asL dep) && (independantCommaExpaux (List.tl liste) asL dep) 
	





(*si id est un champ de struct alors le nom du champ sinon construire le nom isindependent maxinit listeIntersection lesAs*)
and isindependent  listeIntersection lesAs listeDep =
if listeIntersection = [] then (true,listeDep)
else
begin
	let (first, next) = (List.hd listeIntersection, List.tl listeIntersection) in

	let (btype, isdeftype) = 
			if List.mem_assoc first !listAssocIdType then (getBaseType (List.assoc first !listAssocIdType), true) 
			else 
				if List.mem_assoc first !listeAssosPtrNameType then (getBaseType (List.assoc first !listeAssosPtrNameType), true) 
				else (INT_TYPE, false)
	in

	if (isdeftype)= true then 
	begin
		let (isStruct, _) = isStructAndGetIt btype   in
		if isStruct then 
		begin
			if (existeAffectationVarListe first lesAs ) then 
			begin 
				(	match (ro first lesAs ) with 
					ASSIGN_SIMPLE (id, EXP(valeur)) ->  
						 let (resbool, resliste) = isindependent next lesAs listeDep in 
						 (resbool, List.append [first] resliste)
				
					| _ ->  ((*Printf.printf "  isindependent %s  not single assign \n" first ;*) (false,[])))
			end
			else ((*Printf.printf "  isindependent %s  not exist \n" first ;*) (false,[]))
		end
		else ((*Printf.printf "  isindependent %s  not struct \n" first ;*) (false,[]))
	end
	else (false,[])
end


let rec hasSygmaExp e =
(*Printf.printf "  asSygmaExp \n";*)
match e with
	| UNARY (_, exp1) 				-> 	hasSygmaExp exp1 
	| BINARY (_, exp1, exp2) 		-> 	hasSygmaExp exp1 || hasSygmaExp exp2
	| QUESTION (exp1, exp2, exp3) 	->  hasSygmaExp exp1 || hasSygmaExp exp2 || hasSygmaExp exp3
	| CAST (_, exp1) 				->	hasSygmaExp exp1 
	| CALL (exp, args) 				->	( match exp with VARIABLE("SYGMA") -> true  |	_->  if args = [] then false  else  List.exists (fun a ->hasSygmaExp a)args	 )
	| INDEX (exp, idx) 				->	hasSygmaExp exp || hasSygmaExp idx
	| EXPR_LINE (expr, _, _) 		->	hasSygmaExp expr
	|_->false
	
and  hasSygmaExpVA eva =
(*Printf.printf "  hasSygmaExp \n";*)
match eva with
	  MULTIPLE -> false
	| EXP (e) -> (*(*hasSygmaExp e*) true*)hasSygmaExp e
		
let applyStoreVA exp a = 
match exp with
	  MULTIPLE -> (*Printf.printf "dans applyStoreVA multiple\n";*) (exp)
	| EXP (e) -> (*Printf.printf "dans applyStoreVA\n";*)
			boolAS := false;  
			let res = applyStore e a  in
			if (!boolAS = false) then EXP(res) else MULTIPLE


let  replaceAll var assign l =
List.map (
fun asC ->
match asC with
	ASSIGN_SIMPLE (id, exp) ->ASSIGN_SIMPLE (id, EXP (remplacerValPar  var assign (expVaToExp exp)) ) 
	|	ASSIGN_DOUBLE (id, i, exp) ->
		 	ASSIGN_DOUBLE   (id, EXP (remplacerValPar  var assign (expVaToExp i)), EXP (remplacerValPar  var assign  (expVaToExp exp)))  
	|	ASSIGN_MEM (id, i, exp) -> 
			ASSIGN_MEM  (id, EXP (remplacerValPar  var assign  (expVaToExp i)), EXP (remplacerValPar  var assign  (expVaToExp exp)))  


)l
		
let listWithoutVarAssignSingle var liste isstruct   =
if isstruct = false then List.filter (fun aS ->  match aS with ASSIGN_SIMPLE (id, _) -> 	(id <> var)  |_ ->  true  ) liste  
else
begin  
	if  (existeAffectationVarListe var liste ) then 
	begin
		let assignBefore =  (ro var liste)  in
(*Printf.printf "dans listWithoutVarAssignSingle liste\n";
		afficherListeAS liste;*)
		let (before, after) =    roavant liste assignBefore  [] in
		
		let nl = if after = [] then before
				 else
				 begin
					let (assign,v) = match assignBefore with ASSIGN_SIMPLE (id, EXP(VARIABLE(v)) ) ->   (VARIABLE(v),v)   |_->(NOTHING,"") in
					if assign != NOTHING && v != var then ((*Printf.printf "dans listWithoutVarAssignSingle liste\n";*)
						List.append before (replaceAll var assign  after) )
						else

(* peut ere que si var dans .. alors nothing ???? COIR*)
					 List.append before after
				end
	in
(*Printf.printf "dans listWithoutVarAssignSingle nl\n";
		afficherListeAS nl;*)
       nl
	end
	else List.filter (fun aS ->  match aS with ASSIGN_SIMPLE (id, _) -> 	(id <> var)  |_ ->  true  ) liste  
end

let listWithoutVarAssignLetfRight   liste =
 List.filter (fun aS ->  
	match aS with 
			ASSIGN_SIMPLE (id, exp) -> if List.mem id (listeDesVarsDeExpSeules (expVaToExp exp))	then false else true
		|	ASSIGN_DOUBLE (id, i, exp)|ASSIGN_MEM (id, i, exp) ->  
				(match i with 
					MULTIPLE ->  true
					| EXP(v1)->
						(match exp with
							MULTIPLE -> true
							| EXP(v2) -> if List.mem id (listeDesVarsDeExpSeules ( v2)) then false
										else  true))
		  
) liste  


let listWithoutIndexAssign n index l =
 List.filter 
	(fun aS -> match aS with ASSIGN_SIMPLE (id, _) -> true |ASSIGN_DOUBLE (id, i, _) -> if id = n &&  (eqindex index  i) then false else true|ASSIGN_MEM (id, i, _) -> if id = n &&  (eqindex index  i) then false else 


true) l  
	

 
let rondListe a1  ro2x =
		
		match ro2x with 
			ASSIGN_SIMPLE (x, exp) ->
			
				isRenameVar := false; 
				let assign =   applyStoreVA exp a1   in	

				let isStruct = if (List.mem_assoc x !listAssocIdType) then  
							   begin let (isstruct, _) =   isStructAndGetIt (List.assoc x !listAssocIdType) in  isstruct end 
							   else 
									if List.mem_assoc x !listeAssosPtrNameType then 
									begin  let (isstruct, _) =   isStructAndGetIt (List.assoc x !listeAssosPtrNameType) in isstruct 
									end
									else begin  false end in
				 
				let hasstructtorename =  !isRenameVar && isStruct in				 
				let na = if isStruct && (existeAffectationVarListe x a1 )  then 
						 begin
							match  (ro x a1)  with 
								ASSIGN_SIMPLE (id, e) -> let assignBefore =  expVaToExp e in
								let expassign = (expVaToExp assign) in
								let res = unionCONSTCOUNPOUND  expassign assignBefore in
								new_assign_simple x 
														(EXP (remplacerValPar  x assignBefore res))
							|_->(*Printf.printf"NOTHING..."; *)new_assign_simple x  (EXP ((expVaToExp assign) ))

						 end 
						 else  	new_assign_simple x assign in
			([ na], listWithoutVarAssignSingle x a1 hasstructtorename )
				
		|	ASSIGN_DOUBLE (x, exp1, exp2) ->  


								
			let index =  applyStoreVA exp1  a1 in
			if (existeAffectationVarIndexListe x a1 index) then
			begin (* affectation de x(i) dans les deux cas *)
					match  (roindex x a1 index)  with 
						ASSIGN_DOUBLE (_, _, e) |ASSIGN_MEM (_,_ , e) -> let assignBefore =  expVaToExp e in
								let expassign = (expVaToExp (applyStoreVA exp2 a1)) in
								let res = unionCONSTCOUNPOUND  expassign assignBefore in
								let na =  new_assign_double x index  (EXP(res)) in 
			    				([na], listWithoutIndexAssign x index a1)
									 
						|_->	
								 

								 let na = new_assign_double x index (applyStoreVA exp2 a1) in 
			   					 ([na], listWithoutIndexAssign x index a1)
			end
			else
			begin
				 if couldExistAssignVarIndexList x a1 index then   ([new_assign_double x index MULTIPLE], a1)
								 
				 else (* n'appartient pas à ro1*)	 	([new_assign_double x index (applyStoreVA exp2  a1)], a1)
			end		
		|	ASSIGN_MEM (x, exp1, exp2) ->   
	 		 
			let index =  (applyStoreVA exp1  a1) in
			let assign = (applyStoreVA exp2  a1) in
			let (t,i,isOk) =getArrayAssignFromMem  x index in
			let id = if  String.length x > 1 then 
											if (String.sub x  0 1)="*" then 
												(String.sub x 1 ((String.length x)-1) ) 
											else (x )
									else (x ) in  	 

			
			if (existeAffectationVarIndexListe x a1 index) then
			begin (* affectation de x(i) dans les deux cas *)
				let  ro2avant = (roindex x a1 index)  in

				match  ro2avant with 
					ASSIGN_MEM (_, _, e) -> 
						let assignBefore =  expVaToExp e in
						let expassign = (expVaToExp assign) in
						let res = unionCONSTCOUNPOUND  expassign assignBefore in
						let nres = if t != "" then 
									remplacerValPar  id (INDEX(VARIABLE(t),expVaToExp i))
									 res 
									else res in
						(*if  x = "*c" (*&& res != expassign*) then (  

										Printf.printf "Beforen as mem %s\n"x  ;
										print_expression    (expVaToExp assign) 0;new_line(); flush() ;space(); flush(); new_line(); flush();


											Printf.printf "Beforen\n"  ;
										print_expression    assignBefore 0;new_line(); flush() ;space(); flush(); new_line(); flush();
										new_line(); flush() ;space(); flush(); new_line(); flush();
Printf.printf "nres\n"  ;
										print_expression    nres 0;new_line(); flush() ;space(); flush(); new_line(); flush();
										new_line(); flush() ;space(); flush(); new_line(); flush();

											);*)
						 
						let (na,istab,tab,i) = getArrayAssign x index (EXP(nres))  in
						let (resb,aa) = 
								if istab then (  [na],listWithoutIndexAssign tab i a1) else ([na],a1) in
						 (resb, listWithoutIndexAssign x index aa)
									 
					|_-> 				
						let nres = if t != "" then 
									remplacerValPar  id (INDEX(VARIABLE(t),expVaToExp i))
									(expVaToExp assign) 
									else expVaToExp assign in
		 
						 let (na,istab,tab,i) = getArrayAssign x index (EXP( nres)) in
						
						  let (res,aa) = if istab then (  [na],listWithoutIndexAssign tab i a1) else ([na],a1) in
						 (res, listWithoutIndexAssign x index aa)(*listWithoutVarAssignSingle x a1 hasstructtorename*)
			end
			else
			begin
				if isOk && (existeAffectationVarIndexListe t a1 i) then
				begin
					let  ro2avant = (roindex t a1 i)  in
					match  ro2avant with 
						ASSIGN_DOUBLE (_, _, e) -> 
								
							let assignBefore =  expVaToExp e in
							let expassign = (expVaToExp assign) in
							let res = unionCONSTCOUNPOUND  expassign assignBefore in
							 
							let nres =  remplacerValPar  id (INDEX(VARIABLE(t),expVaToExp i)) res   in
							 
							let (na,istab,tab,i) = getArrayAssign x index (EXP(nres))  in


	(*if  x = "*c" (*&& res != expassign*) then (

									(*	Printf.printf "Beforen as double %s %s\n"t id ;
										print_expression    (expVaToExp assign) 0;new_line(); flush() ;space(); flush(); new_line(); flush();


											Printf.printf "Beforen\n"  ;
										print_expression    (expVaToExp e) 0;new_line(); flush() ;space(); flush(); new_line(); flush();
										new_line(); flush() ;space(); flush(); new_line(); flush();
Printf.printf "nres\n"  ;*)
										print_expression    nres 0;new_line(); flush() ;space(); flush(); new_line(); flush();
										new_line(); flush() ;space(); flush(); new_line(); flush();


											);*)

							 
 

							let (resb,aa) = 
									if istab then (  [na],listWithoutIndexAssign tab i a1) else ([na],a1) in
							 (resb, listWithoutIndexAssign x index aa)
										 
						|_->  
							 let nassign = remplacerValPar  id (INDEX(VARIABLE(t),expVaToExp i)) (expVaToExp assign) in
							 let (na,istab,tab,i) = getArrayAssign x index (EXP(nassign)) in
				 
							  let (res,aa) = if istab then ( 
									 [na],listWithoutIndexAssign tab i a1) else ([na],a1) in
							 (res, listWithoutIndexAssign x index aa) 
				end
				else
					if couldExistAssignVarIndexList x a1 index || (isOk && (couldExistAssignVarIndexList t a1 i)) then  
						 ([new_assign_mem x index MULTIPLE] , a1)
					else (* n'appartient pas à ro1*)	
						( 		
								let nassign = remplacerValPar  id (INDEX(VARIABLE(t),expVaToExp i)) (expVaToExp assign) in
								let (na,istab,tab,i) = getArrayAssign x index (EXP(nassign)) in
								let (res,aa) = if istab then 
									(  [na],listWithoutIndexAssign tab i a1) else ([na],a1) in
							 (res, listWithoutIndexAssign x index aa)
						)
			end		

		
(*let rechercherToutesLesVariablesDE a1 a2 = rechercheLesVar a2 (rechercheLesVar a1 [])  *)
let rec conslist l1 l2 a2 =
if l2 = [] then []
else
	if l1 = [] then l2
	else
	begin 
		let (x,suite) =(List.hd l1, List.tl l1) in
		if (existeAffectationVarListe x a2) then conslist suite l2 a2 
		else List.append [x] (conslist suite l2 a2 )
	end

let rec consRondList a1  revl2=
	if revl2 = [] then a1
	else
	begin
		let (first, next) = (List.hd  revl2, List.tl  revl2) in
	(*	let filtera1 = listWithoutVarAssignLetfRight   a1 in *)
		
		let (nax,newa1)= (rondListe a1  first ) in
(*Printf.printf "les as 1 \n" ;
		afficherListeAS a1;
		Printf.printf "fin \n";
		Printf.printf "les as 2 \n" ;
		afficherListeAS a2;
		Printf.printf "fin \n";
		Printf.printf "les newa1 \n" ;
		afficherListeAS newa1;
		Printf.printf "fin \n";
		Printf.printf "les nax \n" ;
		afficherListeAS nax;
		Printf.printf "fin \n";*)
		consRondList (List.append newa1 nax)  next  
	end


let rond a1 a2 =(* avant new*)
(* pour tout x appartenant à a1 ou à a2 *)
(*Printf.printf "rond\n";*)

if a1 = [] then   a2
else
	if a2 = [] then   a1
	else
	begin
		(*Printf.printf "les as 1 \n" ;
		afficherListeAS a1;
		Printf.printf "fin \n";
		Printf.printf "les as 2 \n" ;
		afficherListeAS a2;
		Printf.printf "fin \n";*)
		 
		(*let l2 = rechercheLesVar a2 [] in 

			(*let listeDesVara1Eta2 = conslist l1 l2 a2   in *)
Printf.printf "l2\n";
List.iter(fun x ->Printf.printf "%s\t"x)l2;
Printf.printf "\nl2 fin\n";*)
			(*let revl2 =  List.rev a2  in*)

			  consRondList a1  a2(*revl2*) 
			
	end


let rec consArraySum var min max tab1 indexexp a  =
	let expMin =  CONSTANT(CONST_INT(Printf.sprintf "%d" min)) in
	let expIndex = remplacerValPar  var expMin indexexp in
	if (existeAffectationVarIndexListe tab1 a (EXP(expIndex))) then
	begin
		let first = (match roindex tab1 a (EXP(expIndex)) with ASSIGN_DOUBLE  (_, _, EXP(exp2))-> exp2  | 	_->NOTHING) in
		if first = NOTHING then NOTHING
		else
		begin
			if min + 1 <= max then (* cons next summation *)
			begin
				let nextSum = consArraySum var (min + 1) max tab1 indexexp a in
				if nextSum = NOTHING then NOTHING
				else BINARY(ADD, first, nextSum)
			end
			else first
		end
	end
	else NOTHING



let estModifie = ref false
let listeDesCloseChanged = ref []

let closeForm assign varB listeDesVarModifiees = 
estModifie := true;
let n =   CROISSANT      in
let (predna,na) =
(	match assign with
		ASSIGN_MEM (id, e1, e2) ->
		if id =varB then begin estModifie:= false; (assign, assign) end
		else 
		begin
		(	match e1 with 
			MULTIPLE ->  listeDesVarDependITitcour :=List.append !listeDesVarDependITitcour [assign] ;(assign, assign)
			| EXP(v1)->
				if List.mem id (listeDesVarsDeExpSeules v1)then 
				begin
				(	match e2 with
					MULTIPLE -> listeDesVarDependITitcour :=List.append !listeDesVarDependITitcour [assign] ;(assign, assign)
					| EXP(v2) -> if List.mem id (listeDesVarsDeExpSeules v2) then  (assign,ASSIGN_MEM  (id, MULTIPLE, MULTIPLE) )
								else  (assign, assign) 
				)
				end 
				else (assign, assign))		
		 end
	 |ASSIGN_DOUBLE (id,e1,e2) ->(*Printf.printf "closeForm varB ASSIGN_DOUBLE = %s id %s =" varB id;  *)
		if id =varB then begin estModifie:= false; (assign, assign) end
		else 
		begin
		(	match e1 with 
			MULTIPLE ->  listeDesVarDependITitcour :=List.append !listeDesVarDependITitcour [assign] ;(assign, assign)
			| EXP(v1)->
				if List.mem id (listeDesVarsDeExpSeules v1)then 
				begin
				(	match e2 with
					MULTIPLE -> listeDesVarDependITitcour :=List.append !listeDesVarDependITitcour [assign] ;(assign, assign)
					| EXP(v2) -> if List.mem id (listeDesVarsDeExpSeules v2) then  (assign,ASSIGN_DOUBLE  (id, MULTIPLE, MULTIPLE) )
								else  (assign, assign) 
				)
				end 
				else (assign, assign))		
		 end
	|ASSIGN_SIMPLE (id, e)->	

	if id = varB then begin estModifie:= false; (assign, assign) end
	else
	begin
		let varBPUN = BINARY(ADD, VARIABLE varB, CONSTANT(CONST_INT("1"))) in
	(	match e with 
		MULTIPLE ->   	(*Printf.printf "closeForm varB ASSIGN_SIMPLE id %s = MULTIPLE\n"  id;);*)listeDesVarDependITitcour :=List.append !listeDesVarDependITitcour [assign] ;(assign, assign)
		|EXP (exp) ->
		(	match exp with
			UNARY (op, exp1) ->(*Printf.printf "closeForm varB ASSIGN_SIMPLE = %s id %s = UNARY" varB id;  *)
			(	match op with
				POSINCR|PREINCR ->  listeDesCloseChanged := List.append [id] !listeDesCloseChanged;(assign,ASSIGN_SIMPLE ( id, EXP(BINARY(ADD, exp1,varBPUN)) ) ) (*il faut * it(i+1?)*)
				| POSDECR |PREDECR-> listeDesCloseChanged := List.append [id] !listeDesCloseChanged;(assign,ASSIGN_SIMPLE ( id, EXP(BINARY(SUB, exp1,varBPUN)) )) 
				| MINUS ->  
					if List.mem id (listeDesVarsDeExpSeules exp1) then  
					begin
								listeDesCloseChanged := List.append [id] !listeDesCloseChanged;
								(assign,ASSIGN_SIMPLE ( id, EXP(BINARY (MUL, exp1, 
									CALL (VARIABLE("pow"),List.append [CONSTANT(CONST_INT("-1"))] [varBPUN])))) )	
					end
					else (assign, assign)
					
				| _ -> 		if List.mem id (listeDesVarsDeExpSeules exp1) then 
							((*Printf.printf "closeForm varB ASSIGN_SIMPLE = %s id %s = UNARY" varB id;*)	(assign,ASSIGN_SIMPLE (id,MULTIPLE)) )
							else (assign, assign) 
			)	
			| BINARY (op, exp1, exp2) ->(*Printf.printf "closeForm varB ASSIGN_SIMPLE = %s id %s = BINARY" varB id;  *)
				let varBPUN = BINARY(ADD, VARIABLE varB, CONSTANT(CONST_INT("1"))) in
				let (varE1,varE2) = (listeDesVarsDeExpSeules exp1,listeDesVarsDeExpSeules exp2) in 
				let (estVarE1, estVarE2)  = ( List.mem id varE1 ,List.mem id varE2 ) in
				(* if antidependance alors c'est pas id mais une variable de boucle autre *)
				if (estVarE1 = false) && (estVarE2 = false) then 	(assign, assign) (*constant*)
				(* antidépendance si exp1 ou exp2 contiennent des variables modifiées par la boucle *)
				else
				begin
				(	match op with
					ADD| SUB| MUL| DIV| MOD	| SHL | SHR ->
						let valexp =calculer (EXP(exp))	n [] 1 in
						if estVarDsExpEval id valexp = false then (* type x = cte*) (assign, assign) 
						else if estAffine id valexp then
							 begin
								listeDesCloseChanged := List.append [id] !listeDesCloseChanged;
								let (a,b) = calculaetbAffineForne id valexp in	 					
								let var1 = expressionEvalueeToExpression (evalexpression a) in
								let var2 = expressionEvalueeToExpression(evalexpression b) in	
								if var1 = CONSTANT(CONST_INT("1")) then (* type x = x + cte *)
								begin
									(*ICI*)
									(assign,ASSIGN_SIMPLE (id,EXP(BINARY(ADD, VARIABLE(id), 
										BINARY(MUL,  var2, varBPUN)))))
								end
								else  if estNul b then (* type x = ax*) 		
										(assign,ASSIGN_SIMPLE  (id, EXP(BINARY(MUL, 
											VARIABLE(id),CALL (VARIABLE("pow"),   List.append [var1] [ varBPUN ])))))
									  else(* type x = ax+b*) 										
										(assign,ASSIGN_SIMPLE (	id, 
										EXP(BINARY(ADD, BINARY(MUL, var1, VARIABLE(id)), BINARY(MUL, var2, geometrique var1 varB)))))
							 end
							 else (assign,ASSIGN_SIMPLE (id,MULTIPLE))
					| ADD_ASSIGN | SUB_ASSIGN -> 
						let opaux = (if (op = ADD_ASSIGN) then ADD else SUB) in
						let valexp =calculer (EXP(exp2)) n [] 1 in
						if estVarDsExpEval id valexp = false then (* type x = x+b*) 
						begin
							listeDesCloseChanged := List.append [id] !listeDesCloseChanged;
							(assign,ASSIGN_SIMPLE (id,EXP(BINARY(opaux, VARIABLE(id),  BINARY(MUL,  exp2, VARIABLE(varB))))))
						end
						else (* type x = ax+b*) 
							if estAffine id valexp then
							begin
								listeDesCloseChanged := List.append [id] !listeDesCloseChanged;
								let (a,b) = calculaetbAffineForne id valexp in	 					
								let var1 =  expressionEvalueeToExpression (evalexpression a)in
								let var2 = expressionEvalueeToExpression (evalexpression b) in	
								let vara =  BINARY (opaux,  CONSTANT(CONST_INT("1")), var1 )  in
								if estNul b then (* type x = ax*) 	
									(assign,ASSIGN_SIMPLE ( id, EXP(BINARY (MUL, VARIABLE(id), 
											  CALL (VARIABLE("pow"), List.append  [vara]  [varBPUN] )))))
								else(* type x = ax+b*) 										
									(assign,ASSIGN_SIMPLE (	id, EXP(BINARY(ADD, BINARY (MUL, vara, VARIABLE(id)),
												BINARY(MUL, var2, geometrique vara varB ) )) ))
							end
						else (assign,ASSIGN_SIMPLE (id,MULTIPLE))
					| MUL_ASSIGN	| DIV_ASSIGN | MOD_ASSIGN | SHL_ASSIGN | SHR_ASSIGN-> 
						let valexp =calculer  (EXP(exp2)) n [] 1 in
						if estVarDsExpEval id valexp = false then (* type x = x*cte*) 
						begin
							listeDesCloseChanged := List.append [id] !listeDesCloseChanged;
							(assign,ASSIGN_SIMPLE  (id, EXP(BINARY( op, VARIABLE(id), CALL (VARIABLE("pow"), List.append [exp2] [ varBPUN ] )))))
						end
						else (assign,ASSIGN_SIMPLE (id,MULTIPLE)	)		
					| _-> if List.mem id (listeDesVarsDeExpSeules exp) then (assign, ASSIGN_SIMPLE ( id, MULTIPLE))
						  else (assign, assign)
				)
				end (* binary*)
			| _-> (*  *)
				   if List.mem id (listeDesVarsDeExpSeules exp) then 
					((*Printf.printf "closeForm varB OTHER = %s id %s = MULTIPLE \n" varB id; 	*)	(assign,ASSIGN_SIMPLE ( id, MULTIPLE)) )
					else (assign, assign) 
		))
	end
)	in

(*afficherListeAS [na] ;new_line();
Printf.printf "closeForm = \n" ; afficherListeAS [assign] ;new_line();*)
if na != assign then 
begin
	
	listeDesVarDependITitcour :=List.append !listeDesVarDependITitcour [na];
	(predna,na, [])
end
(*if !estModifie = true then listeDesVarDependITitcour :=List.append !listeDesVarDependITitcour [na];*)
else begin (*Printf.printf "closeForm =other\n" ; afficherListeAS [assign] ;new_line(); *)(predna,na, [na])end
			

let rec majexpaux var e	=
 match e with
	 	UNARY (op, exp) 		-> 	  UNARY (op, (majexpaux var exp))
	| 	BINARY (op, exp1, exp2) ->    BINARY (op, (majexpaux var exp1),  (majexpaux var exp2))
	| 	QUESTION (exp1, exp2, exp3)-> QUESTION ((majexpaux var exp1), (majexpaux var exp2), (majexpaux var exp3)) 
	| 	CAST (typ, exp) 		->	  CAST (typ, (majexpaux var exp))	
	| 	CALL (exp, args) 		->	  CALL (exp, (List.map (fun e -> majexpaux var e)args)) 
	| 	VARIABLE id			->	      if id = var then   BINARY(SUB, VARIABLE id, CONSTANT(CONST_INT("1")) ) 
									  else e
	| 	EXPR_SIZEOF exp 		->	  EXPR_SIZEOF  (majexpaux var exp)
	| 	INDEX (exp, idx) 		->	  INDEX ( (majexpaux var exp), idx)
	| CONSTANT ( CONST_COMPOUND expsc)  -> CONSTANT ( CONST_COMPOUND ( List.map(fun e-> majexpaux var e)expsc))
	| COMMA exps 					->	(COMMA ( List.map (fun e ->majexpaux var e) exps))

(*	| 	MEMBEROF (exp, fld) 	->	  MEMBEROF ( (majexpaux var exp) , fld)
	| 	MEMBEROFPTR (exp, fld) 	->	  MEMBEROFPTR ( (majexpaux var exp) , fld)
*)
	|	_ ->	e

let majexpauxaux varB e = match e with MULTIPLE -> MULTIPLE |EXP  (expr) ->  EXP(majexpaux varB expr )


let  rec majexpauxInit var e	init =
 match e with
	 	UNARY (op, exp) 		-> 	UNARY (op, (majexpauxInit var exp init))
	| 	BINARY (op, exp1, exp2) -> 	BINARY (op, (majexpauxInit var exp1 init),  (majexpauxInit var exp2 init))
	| 	QUESTION (exp1, exp2, exp3)-> QUESTION ((majexpauxInit var exp1 init), (majexpauxInit var exp2 init), (majexpauxInit var exp3 init)) 
	| 	CAST (typ, exp) 		->	CAST (typ, (majexpauxInit var exp init))	
	| 	CALL (exp, args) 		->	 CALL (exp, (List.map (fun e -> majexpauxInit var e init)args))
	| 	VARIABLE id				->	if id = var then   init else e
	| 	EXPR_SIZEOF exp 		->	EXPR_SIZEOF  (majexpauxInit var exp init)
	| 	INDEX (exp, idx) 		->	INDEX ( (majexpauxInit var exp init), idx)
	| CONSTANT ( CONST_COMPOUND expsc)  -> CONSTANT ( CONST_COMPOUND ( List.map(fun e-> majexpauxInit var e init)expsc))
	| COMMA exps 					->	(COMMA ( List.map (fun e ->majexpauxInit var e init) exps))
(*	| 	MEMBEROF (exp, fld) 	->	MEMBEROF ( (majexpauxInit var exp init) , fld)
	| 	MEMBEROFPTR (exp, fld) 	->	MEMBEROFPTR ( (majexpauxInit var exp init) , fld)
*)
	|	_ ->	e
	
let majexpauxauxInit varB e init= (* replace varB by init expression*)
match e with MULTIPLE -> MULTIPLE |EXP  (expr) -> EXP(majexpauxInit varB expr init)

let remplacer varB assign = 
	match assign with
	ASSIGN_SIMPLE (id, e)->         if id = varB then assign else ASSIGN_SIMPLE (id, majexpauxaux varB e)
	|   ASSIGN_DOUBLE (id,e1,e2) -> if id = varB then assign else ASSIGN_DOUBLE  (id, majexpauxaux varB e1, majexpauxaux varB e2)
	|   ASSIGN_MEM (id, e1, e2) -> if id = varB then assign else ASSIGN_MEM (id, majexpauxaux varB e1, majexpauxaux varB e2)




let rec replaceVarbyinitForEachInst var inst init =
	match inst with
	VAR ( id, expVA1) 				->	
		if List.mem var (listeDesVarsDeExpSeules (expVaToExp(expVA1))) then  VAR ( id, majexpauxauxInit var expVA1 init)  else  inst 		
	| TAB ( id, expVA1, expVA2) 	->	
		let newe1 = if List.mem var (listeDesVarsDeExpSeules (expVaToExp(expVA1)))  then majexpauxauxInit var expVA1 init else expVA1 in
		let newe2 =	if List.mem var (listeDesVarsDeExpSeules (expVaToExp(expVA2)))  then majexpauxauxInit var expVA2 init else expVA2 in
	 	TAB ( id, newe1, newe2) 		
	|  MEMASSIGN ( id, expVA1, expVA2)	->	
		let newe1 = if List.mem var (listeDesVarsDeExpSeules (expVaToExp(expVA1)))  then majexpauxauxInit var expVA1 init else expVA1 in
		let newe2 =	if List.mem var (listeDesVarsDeExpSeules (expVaToExp(expVA2)))  then majexpauxauxInit var expVA2 init else expVA2 in
	 	MEMASSIGN ( id, newe1, newe2) 	
			
	| IFVF ( expVA1, i1, i2) 		->
		let newe1 =	if List.mem var (listeDesVarsDeExpSeules (expVaToExp(expVA1))) then majexpauxauxInit var expVA1 init else expVA1 in
		IFVF ( newe1, replaceVarbyinitForEachInst var i1 init ,replaceVarbyinitForEachInst var i2 init ) 		
	| IFV ( expVA1, i1) 		->
		let newe1 =	if List.mem var (listeDesVarsDeExpSeules (expVaToExp(expVA1))) then majexpauxauxInit var expVA1 init else expVA1 in
		IFV ( newe1,replaceVarbyinitForEachInst var i1 init ) 	
	| BEGIN (liste)	-> BEGIN ( List.map (fun i -> replaceVarbyinitForEachInst var i init ) liste)		
	| FORV ( num, id, expVA1, expVA2, expVA3, n, i) -> 	
		let newe1 =if List.mem var (listeDesVarsDeExpSeules (expVaToExp(expVA1))) then majexpauxauxInit var expVA1 init else expVA1 in
		let newe2 =	if List.mem var (listeDesVarsDeExpSeules (expVaToExp(expVA2))) then majexpauxauxInit var expVA2 init else expVA2 in
		let newe3 =	if List.mem var (listeDesVarsDeExpSeules (expVaToExp(expVA3))) then majexpauxauxInit var expVA3 init else expVA1 in
		FORV ( num, id, newe1, newe2, newe3, n, replaceVarbyinitForEachInst var i init )
	| APPEL (num, avant, nom, apres,corps,varB,i) ->APPEL (num, avant, nom, apres,corps,varB,i) (* traiter avant ???*) 


let listeSansAffectVar l var= List.filter (fun e ->  match e with ASSIGN_SIMPLE (id, _)->if id = var then false else true |_->true ) l	

let filterGlobales ascour globales =
List.filter(
fun prem ->
		match prem with  
		ASSIGN_SIMPLE (x, _) 
		| ASSIGN_DOUBLE (x, _, _)  -> if (List.mem x globales ) then begin  true end else false
		| ASSIGN_MEM	 (x, i, _)  -> if (List.mem x globales ) then begin  true end 
			else 
			begin
				let listeDesVar = listeDesVarsDeExpSeules (expVaToExp (i)) in
				let vdij = ( intersection listeDesVar  globales) in 
				if vdij =[] then
				false
				else ((*Printf.printf "pointeur sur globale filterGlobales\n";*)true)
			end
) ascour



let rec filterGlobalesAndOthers ascour globales =
if ascour = [] then ([], [])
else 
begin
	let (prem, next) = (List.hd ascour, List.tl ascour) in
	let (nextGlobal, nextOthers) =filterGlobalesAndOthers next globales in


	(match prem with  
		ASSIGN_SIMPLE (x, _)
		| ASSIGN_DOUBLE (x, _, _) -> 
			if (List.mem x globales ) then  (List.append [prem] nextGlobal, nextOthers)  else (nextGlobal, List.append [prem] nextOthers)
		| ASSIGN_MEM	 (x, i, assign)  -> 
			if (List.mem x globales ) then  (List.append [prem] nextGlobal, nextOthers)  
			else 
			begin			
				let listeDesVar = listeDesVarsDeExpSeules (expVaToExp (i)) in
				let vdij = ( intersection listeDesVar  globales) in 
				if vdij =[] then (nextGlobal, List.append [prem] nextOthers)
				else 
				(		
					
					let na =
						begin
							let (tab1,_, _) =getArrayNameOfexp (expVaToExp i) in
							if tab1 = "" then ((*Printf.printf "ELSE %s ptr %s \n" tab1 x; *) prem)
							else
							begin
								
								let (indexexp , _) = consArrayFromPtrExp (expVaToExp i )  tab1 in
								if indexexp != NOTHING then  
								begin
(*Printf.printf "pointeur sur globale filterGlobalesAndOthers OK %s\n" tab1; *)
									new_assign_double tab1 (EXP(indexexp)) assign 
								end
								else 
								begin
(*Printf.printf "pointeur sur globale filterGlobalesAndOthers MULTIPLE %s\n" tab1; *)
									new_assign_double tab1 MULTIPLE MULTIPLE
								end 
							end 
						end	in

						(List.append [na] nextGlobal, nextOthers)
				)(*(nextGlobal, List.append [prem] nextOthers)*)
			end
		)
end

 




let isVarTrue  var e=
	match e with
		VARIABLE v-> if var =v then true else false
		|_-> false


let consSETASSIGN var firstAssign secondAssign =

(*Printf.printf "consSETASSIGN %s\n" var;*)
	match firstAssign with  
		ASSIGN_SIMPLE (var, EXP(valeur1)) ->
				(match secondAssign with 
							ASSIGN_SIMPLE (var, EXP(valeur2)) ->
 								let (isTruecteArg1, v1) =isTrueConstant valeur1 in
								let (isTruecteArg2, v2) =isTrueConstant valeur2 in
								if isTruecteArg1 then
								begin
									if isTruecteArg2 then
										if v1 = v2 then ASSIGN_SIMPLE (var, EXP(valeur1))
										else ASSIGN_SIMPLE (var, EXP(CALL (VARIABLE "SET" , List.append [valeur1] [valeur2])))
									else 
										if isVarTrue  var valeur2  then ASSIGN_SIMPLE (var, EXP(valeur1))
										else ASSIGN_SIMPLE (var,MULTIPLE)
								end
								else 
								begin
(*Printf.printf "consSETASSIGN 3 %s\n" var;*)
									if isVarTrue  var valeur1  then ASSIGN_SIMPLE (var, EXP(valeur2))
									else ASSIGN_SIMPLE (var,MULTIPLE)
									 
								end
							|_-> ASSIGN_SIMPLE (var,MULTIPLE)
				)

		

		|_-> ASSIGN_SIMPLE (var,MULTIPLE) 


let consMultiSET var firstAssign secondAssign =
match firstAssign with  
		 ASSIGN_DOUBLE (var, e1, EXP(valeur1))   ->
			(match secondAssign with  ASSIGN_DOUBLE (var, e2, EXP(valeur2))->
										if e1 = e2 then
										begin
											let (isTruecteArg1, v1) =isTrueConstant valeur1 in
											let (isTruecteArg2, v2) =isTrueConstant valeur2 in
											if isTruecteArg1 then
											begin
												if isTruecteArg2 then 
													if v1 = v2 then ASSIGN_DOUBLE (var, e1,  EXP(valeur1))
													else ASSIGN_DOUBLE (var, e1, EXP(CALL (VARIABLE "SET" , List.append [valeur1] [valeur2])))
												else 
													if isVarTrue  var valeur2  then  ASSIGN_DOUBLE (var, e1,  EXP(valeur1))
													else ASSIGN_DOUBLE (var, e1,MULTIPLE)	

											end
											else  
											begin
												if isVarTrue  var valeur1  then  ASSIGN_DOUBLE (var, e1,  EXP(valeur2))
													else ASSIGN_DOUBLE (var, e1,MULTIPLE)	
											end
										end

										else  ASSIGN_DOUBLE (var, e1,MULTIPLE)
									  |_->  ASSIGN_DOUBLE (var, e1,MULTIPLE))
		| ASSIGN_MEM	 (var, e1, EXP(valeur1)) ->
			(match secondAssign with  ASSIGN_MEM (var, e2, EXP(valeur2))->

										if e1 = e2 then 
										begin
  
											
											let (isTruecteArg1, v1) =isTrueConstant valeur1 in
											let (isTruecteArg2, v2) =isTrueConstant valeur2 in
	
											(
														if isTruecteArg1 then
														begin 

														(*listMultiSet*)


															if isTruecteArg2 then 
																if v1 = v2 then 
																	ASSIGN_MEM (var, e1,  EXP(valeur1))
																else ASSIGN_MEM (var, e1, EXP(CALL (VARIABLE "SET" , List.append [valeur1] [valeur2])))
															else 
																if isVarTrue  var valeur2  then  ASSIGN_MEM (var, e1,  EXP(valeur1))
																else ASSIGN_MEM (var, e1,MULTIPLE)	
														end
														else
														begin
															 if isVarTrue  var valeur1  then  ASSIGN_MEM (var, e1,  EXP(valeur2))
																else ASSIGN_MEM (var, e1,MULTIPLE)	
														end)
										end
										else ASSIGN_MEM (var, e1,MULTIPLE)
									  |_-> ASSIGN_MEM (var, e1,MULTIPLE))
		| ASSIGN_DOUBLE (var, e1, MULTIPLE)   ->ASSIGN_DOUBLE (var, e1, MULTIPLE) 
		| ASSIGN_MEM	 (var, e1, MULTIPLE) ->ASSIGN_MEM(var, e1, MULTIPLE) 
		|_-> ASSIGN_SIMPLE (var,MULTIPLE) 
		


let structmultidef var firstAssign secondAssign =
 

	let (btype, isdeftype) = 
			if List.mem_assoc var !listAssocIdType then (getBaseType (List.assoc var !listAssocIdType), true) 
			else 
				if List.mem_assoc var !listeAssosPtrNameType then (getBaseType (List.assoc var !listeAssosPtrNameType), true) 
				else (INT_TYPE, false)
	in

	if isdeftype then 
	begin
		let (isStruct, typ) = isStructAndGetIt btype    in
		let listType = (match typ with  
						TYPEDEF_NAME s ->
									if List.mem_assoc s !listAssosIdTypeTypeDec then 
										( match  List.assoc s !listAssosIdTypeTypeDec  with  STRUCTORUNION (l )->l |_-> [])
									else []
						|_-> [] )in

		
		if isStruct then 
		begin 	
			(match firstAssign with 
				ASSIGN_SIMPLE (id, EXP(valeur)) ->  
					let (exp, isCCOMP) = getStuctValueOfExpression valeur typ in	
					(	match secondAssign with 
						ASSIGN_SIMPLE (id, EXP(valeur)) ->  
							let (exp2, isCCOMP2) = getStuctValueOfExpression valeur typ in		

							if exp2 = exp && exp != [] then 	ASSIGN_SIMPLE (id, EXP(valeur))			
							else 	ASSIGN_SIMPLE (id, 
								EXP(CONSTANT(	CONST_COMPOUND
											(compareComma exp exp2 [] listType)
									)))		
								
						|_->	
								
							 ASSIGN_SIMPLE (id, MULTIPLE) (* not single assign  type *)
					)
				|_->  ASSIGN_SIMPLE (var, MULTIPLE) (* not single assign  type *)
			)
		end
		else (*ASSIGN_SIMPLE (var, MULTIPLE)*)(* not a  type *)consSETASSIGN var firstAssign secondAssign 
	end
	else (* ASSIGN_SIMPLE (var, MULTIPLE)*)(* unknowned type *)consSETASSIGN var firstAssign secondAssign 


let absMoinsT x a1 a2 =
(*Printf.printf "dans absMoinsT variable traitee %s \n" x;*)
	if ( existeAffectationVarListe x a1) then
	begin
(*Printf.printf "dans a1 %s \n" x;*)
		let ro1 = ro x a1 in 
		if ( existeAffectationVarListe x a2) then
		begin
(*Printf.printf "dans a2 %s \n" x;*)
			let ro2 = ro x a2 in
			if ro1 = ro2 		then ro1
			else 
			begin
				(*Printf.printf "MULTIPLE %s dans absMoinsT\n" x;*)
				match ro1 with
						ASSIGN_SIMPLE (_, _)-> (*Printf.printf "MULTIPLE %s dans absMoinsT\n" x; *)structmultidef x ro1 ro2

(*ASSIGN_SIMPLE (x, MULTIPLE)*)(*var MULTIPLE def voir si on
						utilise le max*)
					|	ASSIGN_DOUBLE (_, exp, _)-> consMultiSET  x ro1 ro2
					|   ASSIGN_MEM (_, exp, _)->consMultiSET  x ro1 ro2
				
			end 
		end
		else begin(* rien pour x dans a2 on garde ce qu'il y a dans a1 *) (*Printf.printf "que dans a1 %s \n" x;afficherAS ro1;*) ro1 end
	end 
	else 
	begin
		(* rien pour x dans a1 on garde ce qu'il y a dans a2 *) 
		ro x a2 (* existe car dans au moins un] des deux ensembles*)		
	end	
	
let getVarDeAffect affect = match affect with ASSIGN_SIMPLE (id, _) ->id |	ASSIGN_DOUBLE (id, _, _) -> id|	ASSIGN_MEM (id, _, _) -> id


let rec paux a1 a2 l =
if l = [] then [] else  List.append  [absMoinsT (List.hd l) a1 a2 ] (paux a1 a2 (List.tl l) ) 






let  produit a1 a2  = 
(*Printf.printf "produit\n";*)
 paux a1 a2 (rechercheLesVar a2  (rechercheLesVar a1 []))

let absMoinsTEm x a1 a2 listeT=
let res =	
	if ( existeAffectationVarListe x a1) then
	begin
		let ro1 = ro x a1 in 
		
		
		if ( existeAffectationVarListe x a2)  then
		begin
			
		(*let ro2avant = ro x a2 in
			 
			let (before, _) =    roavant ro2avant a2  [] in
			let (r1,_) = rondListe before ro2avant in*)
			

			let (r,_) = rondListe a1 ( ro x a2 ) in
			let ro2 = if r= [] then ro1 else  List.hd r in
			
			if ( List.mem x listeT) then   ro2 (*changed into the two alternatives*)
			else
			begin
				if ro1 =ro2 	then ro1 (*changed into the only one alternative*)
				else 
				begin
					(*Printf.printf "MULTIPLE %s dans absMoinsTEm\n" x;*)
					match ro2 with
							ASSIGN_SIMPLE (_, _)->(*Printf.printf "MULTIPLE %s dans absMoinsTEm 2\n" x;*)
								structmultidef x ro1  ro2 
							(*ASSIGN_SIMPLE (x, MULTIPLE)*)(*var MULTIPLE def voir si on utilise le max*)
						|	ASSIGN_DOUBLE (_, exp, _)-> consMultiSET x ro1 ro2
						|	ASSIGN_MEM (_, exp, _)-> consMultiSET x ro1 ro2
				end 
			end
		end
		else (* rien pour x dans a2 on garde ce qu'il y a dans a1 *) ro1
	end 
	else 
	begin
	(*	let ro2avant = ro x a2 in
			 
			let (before, _) =    roavant  a2 ro2avant [] in
			let (r1,_) = rondListe before ro2avant in
			

			let (r,_) = rondListe a1 (List.hd r1) in*)

		let (r,_) = rondListe a1 (ro x a2) in
		let ro2 = List.hd r in
		if ( List.mem x listeT) then ro2 (* existe car dans au moins un] des deux ensembles*)		
		else
		begin
			let resb = 
				if (String.length x > 4) then
				begin
					let var4 = (String.sub x  0 4) in
					let var3 = (String.sub x  0 3) in
					if  var3 = "ET-" ||  var3 = "EF-" ||  var3 = "IF-" || var3 = "tN-" || var4 = "max-" || var4 = "tni-" ||  var4 = "TWH-"then true else false
				end
				else if (String.length x > 3) then 
						if (String.sub x  0 3) = "ET-" || (String.sub x  0 3) = "EF-" || (String.sub x  0 3) = "IF-" || (String.sub x  0 3) = "tN-" then true else false else false in
			(*let n = rond a1 [ro x a2] in*)
			 
			
			if resb then ro2
			else
			begin
					(*Printf.printf "MULTIPLE %s dans absMoinsTEm 2\n" x;Printf.printf "que dans a1 %s \n" x;afficherAS (ro x a2 );*)
					match ro2  with
							ASSIGN_SIMPLE (x, y)-> 
							if (String.length x > 5) && (String.sub x  0 5) = "__tmp" then ASSIGN_SIMPLE (x, MULTIPLE)
							else
								if y = EXP(VARIABLE(x)) then  (  ro x a2)  else 
								begin
									if !getOnlyBoolAssignment = true then ( ASSIGN_SIMPLE (x, MULTIPLE))
									else if y = MULTIPLE || containtNothing (expVaToExp y )  then ( ASSIGN_SIMPLE (x,MULTIPLE))
								  		 else 
										 begin (*	Printf.printf "MULTIPLE %s dans absMoinsTEm 4\n" x;*)
											match y with 
												EXP(CONSTANT(_)) ->(*Printf.printf "produit 1 %s\n" x;
														afficherAS (ro x a2);space();flush();new_line();*)
														ASSIGN_SIMPLE (x,    EXP(CALL (VARIABLE("SET") , List.append [VARIABLE(x)] [expVaToExp y])))
												| EXP(CALL(VARIABLE"SET", l))->(*Printf.printf "MULTIPLE %s dans absMoinsTEm 4 set\n" x;*)
														(match (List.hd l,List.hd (List.tl l)) with 
																(CONSTANT(_),CONSTANT(_)) -> 
																	ASSIGN_SIMPLE (x, EXP(CALL (VARIABLE("SET") , 
																					List.append [VARIABLE(x)] [expVaToExp y])))
																|_-> ASSIGN_SIMPLE (x,MULTIPLE)
														)														 
								 						(*ASSIGN_SIMPLE (x, MULTIPLE) *)
												|_-> ASSIGN_SIMPLE (x,MULTIPLE)
										 end
								end
						|	ASSIGN_DOUBLE (_, exp, _)-> ASSIGN_DOUBLE (x, exp, MULTIPLE) 
						|	ASSIGN_MEM (_, exp, _)-> ASSIGN_MEM (x, exp, MULTIPLE) 
			end
		end
	end	
in
res


let rec pauxEm a1 a2 l listeT=
if l = [] then [] else  
begin
	let x = (List.hd l) in
	let na =absMoinsTEm x a1 a2 listeT in
	let isChanged = if ( existeAffectationVarListe x a2)  then
						if na = ro x a2 then  false
						else  true 
				else  true
			in

	if isChanged = false then List.append  [na] (pauxEm a1 a2 (List.tl l) listeT) 
	else 
	begin
		List.append  [na] ( pauxEm (rond a1 [na]) a2 (List.tl l) listeT)
	end
end

let produitEm a1 a2 listeT =  pauxEm a1 a2 (rechercheLesVar a2  (rechercheLesVar a1 [])) listeT








let corpsNouv = ref []
let corpsNouvI = ref []
let firstLoop = ref 0

(*let listeApres = ref []*)


let rec listeDesVarDuCorps corps =
match corps with 
	VAR (id, exp) -> List.append [id] (listeDesVarsDeExpSeules  (expVaToExp (exp)))
		
	| TAB (id, exp1, exp2)
	|  MEMASSIGN ( id, exp1, exp2)	->	List.append [id] (List.append (listeDesVarsDeExpSeules  (expVaToExp (exp1)))  (listeDesVarsDeExpSeules  (expVaToExp (exp2))))
	| BEGIN liste -> listeDesVarBegin liste
		
	| IFVF (cond, i1, i2) ->
			List.append (listeDesVarsDeExpSeules  (expVaToExp (cond))) 
						(List.append (listeDesVarDuCorps  i1)  (listeDesVarDuCorps  i2))			
	| IFV ( cond, i1) 	->
			List.append (listeDesVarsDeExpSeules  (expVaToExp (cond)) ) (listeDesVarDuCorps  i1) 	
	| APPEL (_,e,_,s,_,_,_)-> List.append (listeDesVarDuCorps e) (listeDesVarDuCorps s)
	| FORV(_,_,_, exp2, exp3, _, i)->
			List.append (listeDesVarsDeExpSeules  (expVaToExp (exp2)))  
						(List.append  (listeDesVarsDeExpSeules  (expVaToExp (exp3))) (listeDesVarDuCorps  i))  

and listeDesVarBegin liste =
if liste = [] then []
else
begin
	let (first, next) =(List.hd liste, List.tl liste )in
	List.append (listeDesVarDuCorps first) (listeDesVarBegin next)
end

	
let rec splitTotalAndOthers ascour globales rename = 
List.filter(
fun prem ->
		match prem with  
		ASSIGN_SIMPLE (id, _) ->
			if (List.mem id globales ) then true
			else
			begin
				let rep=
					 
						if (String.length id > 4) then
						begin
							let var4 = (String.sub id  0 4) in
							let var3 = (String.sub id  0 3) in
							if var3 = "ET-" ||  var3 = "EF-"  || var3 = "tN-" || var4 = "max-" || var4 = "tni-" || var4 = "TWH-" ||
								 var3 = "IF-" then    (true) 							else  (false)
						end
						else if (String.length id > 3) then 
								if (String.sub id  0 3) = "ET-" || (String.sub id  0 3) = "EF-"  || (String.sub id  0 3) = "tN-" ||
									(String.sub id  0 3) = "IF-"
								 then (true) 	 else (false)
							 else false
					 
					in
				rep
			end
		| ASSIGN_DOUBLE (x, _, _)  -> if (List.mem x globales ) then begin  true end else false
		| ASSIGN_MEM	 (x, i, _)  -> if (List.mem x globales ) then begin  true end 
			else 
			begin
				let listeDesVar = listeDesVarsDeExpSeules (expVaToExp (i)) in
 				let vdij = ( intersection listeDesVar  globales) in 
				if vdij =[] then false else true
			end


)ascour



let rec rewriteEndOthers asl oldOthers newOthers =
if oldOthers = [] || asl = [] || newOthers = [] then asl 
else 
begin
	let (oinit, onext )= (List.hd oldOthers, List.tl oldOthers) in
	let (firstChange, nextchanges) = (List.hd newOthers, List.tl newOthers) in
	let (curAssign, nextAssign) =  (List.hd asl, List.tl asl) in
	if curAssign = oinit then 
			List.append [firstChange] (rewriteEndOthers nextAssign onext nextchanges) 
	else   if List.mem oinit nextAssign then 
				List.append [curAssign] (rewriteEndOthers nextAssign oldOthers newOthers) 
			else List.append [curAssign] (rewriteEndOthers nextAssign onext nextchanges) 
end

let filterIF l =
List.filter (fun e ->  match e with ASSIGN_SIMPLE (id, _)->
  if (String.length id > 3) then
	  begin 
		  if  (String.sub id  0 3) = "ET-" ||  (String.sub id  0 3) = "EF-"  then    true 	else false
	  end 
  else(* if existAssosPtrNameType  id then true else*) false 
  |_->false ) l
let firstWH = ref false
let filterwithoutWH l =
firstWH := true;
List.filter (fun e ->  match e with ASSIGN_SIMPLE (id, _)->
  if (String.length id > 4) then
	  begin 
		  if  (String.sub id  0 4) = "TWH-"   then   if !firstWH then (firstWH := false; true) else false 	else true
	  end 
  else(* if existAssosPtrNameType  id then true else*) true 
  |_->true ) l


let filterwithoutInternal l globales output =
List.filter (fun e ->  match e with ASSIGN_SIMPLE (id, _)->

	if (List.mem id globales ) || List.mem id output then true
	else
	begin		
				let rep=
					 
						if (String.length id > 4) then
						begin
							let var4 = (String.sub id  0 4) in
							let var3 = (String.sub id  0 3) in
							if var3 = "ET-" ||  var3 = "EF-"  || var3 = "tN-" || var4 = "max-" || var4 = "tni-" || var4 = "TWH-" || var4 = "res-"  then    (true) else  (false)
						end
						else if (String.length id > 3) then 
								if (String.sub id  0 3) = "ET-" || (String.sub id  0 3) = "EF-"  || (String.sub id  0 3) = "tN-"   then (true) 	 else (false)
							 else false
					in
				rep
			
	  end 
  
	| ASSIGN_DOUBLE (id, _, _) 	|ASSIGN_MEM (id, _, _)-> if List.mem id globales || List.mem id output then true else false
	 ) l

(*
let filterSortiesGlobalesLoops  listES listGlobales asList    =
	let listeOutput = listeOutputs listES in
asList*)
let estboucle = ref false
let consInitTest varExpVa res =
match varExpVa with EXP(VARIABLE (v)) -> [VAR (v, res)]  |_-> [] 

let rec allthesame l =
if l = [] then true
else
begin
	let(firts, next) = (List.hd l, List.tl l) in
	if next = [] then  true
	else  firts = (List.hd next) &&  allthesame next  
end


let rec evalStore i a g=
match i with 
	VAR (id, exp) -> 

(*listOfMaybeGlobalptr*)
		(*if List.mem_assoc id !listeAssosPtrNameType then if (List.mem x globales ) then*)
		
		let res = rond a [new_assign_simple id exp] in		
		res
	| TAB (id, exp1, exp2) -> (*Printf.printf "evalStore tab\n";*)
		rond a [new_assign_double id exp1 exp2]
		(*afficherListeAS !listeASCourant;*)
	|  MEMASSIGN ( id, exp1, exp2)	->	rond a [new_assign_mem id exp1 exp2];
(*Printf.printf"memassign\n"; afficherListeAS  [new_assign_mem id exp1 exp2];
Printf.printf"memassign as\n";	*)	
	| BEGIN liste -> 
		(*let pred = !listeASCourant in*)
		(traiterSequence liste a g) ;
	(*afficherListeAS !listeASCourant;*)
		 
		
	| IFVF (cond, i1, i2) ->(*Printf.printf "evalStore if then else\n";*)
(*print_expVA cond; new_line();*)


		let myCond =  applyStoreVA (applyStoreVA  cond a) g  in 
		let myTest = calculer myCond  !infoaffichNull  [] 1 in
(*Printf.printf "evalStore if TRUE false\n"; 

print_expVA myCond; new_line();*)

		(*print_expTerm myTest;new_line();*)
		if !estDansBoucle = false then
		begin
			if estTrue myTest then  evalStore i1 a g
			else 
			begin
				if estFalse myTest then evalStore i2 a g
				else
				begin
					(*Printf.printf "\nevalStore if then else IF res test indefini\n";*)
					 listeASCourant := [];
					 let resT = evalStore i1 [] [] in
					
(*Printf.printf "les as de if T \n" ;
afficherListeAS !listeASCourant;
Printf.printf "fin \n";*)
					 let listeIF = (rechercheLesVar resT []) in
					 
					 let resF = evalStore i2 [] [] in	

(*Printf.printf "les as de if T \n" ;
afficherListeAS resF;
Printf.printf "fin \n";*)

					 let listeELSE = (rechercheLesVar resF []) in
					 let inter = intersection listeELSE  listeIF in
					 	
					  let resA = produit resT resF 	  in	
						 
					 produitEm a resA inter	(*produit a resA*)
							(*	afficherListeAS !listeASCourant;*)
				end
			end
		end
		else
		begin
(*Printf.printf "dans boucle\n" ;*)
					(*let ifassign = filterIF a in*)
					 let cTest = (*consInitTest cond myCond*) [] in 
					 let resT = evalStore (BEGIN(List.append cTest [i1])) (*ifassign*)[] [] in
					 let listeIF = (rechercheLesVar resT []) in
					 
					 let resF =  evalStore (BEGIN(List.append cTest [i2] (*ifassign*)))[]  [] in	
(*Printf.printf "evalStore if TRUE false\n"; 

print_expVA myCond; new_line();

print_expTerm myTest;new_line();
Printf.printf "les as de if T \n" ;
afficherListeAS resT;
Printf.printf "fin \n";
Printf.printf "les as de if F \n" ;
afficherListeAS resF;
Printf.printf "fin \n";*)
					 let listeELSE = (rechercheLesVar resF []) in
					 let inter = intersection listeELSE  listeIF in
					 	
					 let resA = produit resT resF  in	
					 
					 produitEm a resA inter
					(* let resA = !listeASCourant in	
						listeASCourant := []; 
					 produitEm a resA inter	;*)
		end;
(*Printf.printf "fin evalStore IF THEN ELSE\n";
print_expVA myCond; new_line();
Printf.printf "les as de if \n" ;
afficherListeAS !listeASCourant;
Printf.printf "fin \n";*)
					
	| IFV ( cond, i1) 		->(*Printf.printf "evalStore if TRUE \n"; *)
		let avant = a in

		let myCond = applyStoreVA (applyStoreVA  cond a) g  in 

		let myTest = calculer myCond  !infoaffichNull  [] 1 in
		(*print_expVA myCond; new_line();

		print_expTerm myTest;new_line();*)
		
		(*if !estDansBoucle = true then Printf.printf "IF DANS BOUCLE\n";*)
		if (!estDansBoucle = false && estTrue myTest)  then evalStore i1 a g
		else if (!estDansBoucle = true) then
			begin
				(*Printf.printf "evalStore if TRUE dans boucle\n"; *)
				(*let ifassign = filterIF a in*)
				let cTest = (*consInitTest cond myCond*) [] in 
				let resT = evalStore (BEGIN(List.append cTest [i1] ))(*ifassign*)[] [] in
				produitEm a resT []
				(*listeASCourant := [];*)

			end
			else 	if (estFalse myTest = true ) then   avant 
					else 
					begin
						(*Printf.printf "if non executé peut etre\n";*) 
						let resT = evalStore i1 [] [] in
						produitEm a resT [] 
					end
(*Printf.printf "fin evalStore IF THEN \n";		
print_expVA myCond; new_line();
Printf.printf "les as de if \n" ;
(*afficherListeAS !listeASCourant;*)
Printf.printf "fin \n";*)
					
	| FORV (num,id, _, _, _, _, inst)	-> 
		estboucle := true;
	(*Printf.printf "\nevalStore boucle executed %d variable %s\n" num id;*)
		if !firstLoop = 0 then firstLoop := num;
		let listePred = !listeDesVarDependITitcour in
		listeDesVarDependITitcour := [];
   		let resT = evalStore inst [] [] in
		estboucle := false;
(*Printf.printf "les as de la boucle avant transfo %d\n" num;
afficherListeAS resT;
Printf.printf "les as de la boucle avant transfo \n";*)
		
		let (newas, oldOthers, newOthers) =(closeFormPourToutXdelisteES resT id (*aS*) ) in
		(*let listeDesnewAffect = List.map (fun a -> remplacer id a) newas in
		Printf.printf "les as de FOR aprescloseform\n" ;
		afficherListeAS newas;
		Printf.printf "fin \n";*)
		(*let listeDesnewAffect = List.map (fun a -> remplacer id a) newas in*)
		(*Printf.printf "contexte\n" ;
		afficherListeAS a;
		Printf.printf "fin \n";*)
		let rewrite = 
		if newOthers != [] then
		(			(*
					Printf.printf "\nothers rewriteAllOthers\n";
						afficherListeAS newOthers;space();flush();new_line();
						Printf.printf "\nend\n";
						Printf.printf "others\n";
						afficherListeAS oldOthers ;space();flush();new_line();
						Printf.printf "\nend\n";*)
					(*Printf.printf "others\n";
						afficherListeAS newas ;space();flush();new_line();
						Printf.printf "\nend\n";*)




				let new_res = rewriteEndOthers newas oldOthers newOthers in
				(*Printf.printf "newasl \n";
					afficherListeAS new_res ;space();flush();new_line();
					Printf.printf "\nend\n";*)
				new_res 
		)
		else newas in




		listeDesVarDependITitcour :=(* rond*) listePred   (*listeDesnewAffect*);
		(*Printf.printf "\nFIN evalStore boucle executed %d variable %s\n" num id;*)
		if num = !firstLoop then begin listeDesVarDependITitcour :=[]; firstLoop :=0 end;
		let res = (rond a   rewrite ) in
		(*Printf.printf "les as de FOR \n" ;
		afficherListeAS res;
		Printf.printf "fin \n";*)
			res
	| APPEL (n,e,nomFonc,s,corpsAbs,varB,rename)->
		if !withoutTakingCallIntoAccount = true then a
		else
		begin

					(*print_string ("Appel fonction definie: "^nomFonc ^"\n");*)

				(*	Printf.printf "evalStore fonction %s  \n" nomFonc ;	*)
					let sorties = (match s with BEGIN(sss)-> sss |_->[]) in

					let affectSortie = evalStore s [] [] in	
					let entrees = (match e with BEGIN(eee) -> eee |_->[]) in
					let isAbs = match corpsAbs with CORPS(_) -> if List.mem_assoc  nomFonc !alreadyEvalFunctionAS then true else false 
								| ABSSTORE(_) -> true in

					let absStore = match corpsAbs with ABSSTORE(a) -> a | _ -> 
									if List.mem_assoc  nomFonc !alreadyEvalFunctionAS then List.assoc nomFonc !alreadyEvalFunctionAS else [] in
		
					if varB = "" then
					begin
						let c = (match corpsAbs with CORPS(x) -> x |_ -> BEGIN([])) in
						(*let corps =   (match corpsAbs with CORPS (BEGIN(ccc)) -> ccc |_->[]) in*)

						(* POUR ESSAYER D'OPTIMISER NE GUARDER QUE LES ENTREES ET LES GLOBALES*)

						 		
						let (globale, others) = filterGlobalesAndOthers a !alreadyAffectedGlobales in
						(*Printf.printf "evalStore fonction pas dans boucle %s  \n" nomFonc ;*)
						(*Printf.printf "evalStore fonction pas dans boucle %s  \n" nomFonc ;
 						afficherUneAffect ((c)); new_line(); Printf.printf "affect a apere reecrire fin\n";*)

						corpsNouv := if (isAbs)
									   then (rond (List.append globale (evalInputFunction a entrees g )) absStore)
								   else (evalStore (c) (List.append globale (evalInputFunction a entrees g)) g);

			
						let rc =  !corpsNouv in listeASCourant := []; 
					(*Printf.printf "contxte \n" ;afficherListeAS rc;Printf.printf "fin liste\n" ;*)
						if sorties <> [] then
						begin
							(*afficherListeAS rc; *)
							List.iter (
								fun sortie -> 
								(match sortie with 
								VAR (id, e) -> 
									let (isOkSortie, isnotchange) =  isOkSortie e rc [] id in
									if isnotchange = false then
										(if isOkSortie then 
											if existAssosArrayIDsize id  then  (getTabAssign sortie rc g )  
													else listeASCourant :=  List.append  [new_assign_simple id  (getSortie e rc g id) ]  !listeASCourant
										else listeASCourant :=  List.append  [new_assign_simple id  MULTIPLE ]  !listeASCourant); 
									()
								| TAB (id, e1, e2) ->  
										let (isOkSortie, isnotchange) =  isOkSortie e2 rc [] id in
									if isnotchange = false then
									begin
										if isOkSortie then 
										begin 
											(getTabAssign sortie rc g )  
			
											
										end
										else listeASCourant := List.append [ASSIGN_DOUBLE (id,  MULTIPLE,  MULTIPLE)] !listeASCourant
									end;
									()
								|MEMASSIGN (id, e1, e2)-> 
									let (isOkSortie, isnotchange) =  isOkSortie e2 rc [] id in
									if isnotchange = false then
									begin
										if isOkSortie then 
											getMemAssign sortie rc  g
										else 
											listeASCourant := List.append [ASSIGN_MEM (id,  MULTIPLE,  MULTIPLE)] !listeASCourant;
									 end;()
								|_->())
								)sorties	
						end  ;


					(*	
	
			
						(*Printf.printf "evalStore fonction %s  \n" nomFonc ;*)
						let nc = rond others     !listeASCourant  in
						(*Printf.printf "contxte \n" ;afficherListeAS nc;Printf.printf "fin liste\n" ;*)
						nc*)
						let nginterne = filterGlobales rc  !alreadyAffectedGlobales  in
						(*let (aPart, _) = splitTotalAndOthers rc in*)

						let returnf = Printf.sprintf "res-%s"  nomFonc in
						if existeAffectationVarListe returnf rc then
						begin
							let affectres = ro returnf rc in
							listeASCourant :=  List.append [affectres] (List.append   nginterne !listeASCourant )
						end
						else listeASCourant :=   (List.append   nginterne !listeASCourant );
			
(*Printf.printf "evalStore fonction %s  \n SORTIE \n" nomFonc ;		*)	

					(*Printf.printf "\nsorties %s depend de var de boucle %s\n" nomFonc varB; afficherListeAS !listeASCourant; Printf.printf "fin sorties\n";*)
						let nc = rond others   !listeASCourant  in
(*afficherListeAS nc;*)
(*print_string ("Appel fonction definie: FIN "^nomFonc ^"\n");*)
						nc
					end
					else 
					begin
						(*	Printf.printf "dans boucle\n";*)
						 estDansBoucle:=true;
						let corps =   (match corpsAbs with CORPS (BEGIN(ccc)) -> ccc | CORPS (ccc) -> [ccc] |_->[]) in

(*if corps =[] then Printf.printf "evalStore fonction dans boucle %s appel %d corps vide...!!!!!!!\n" nomFonc n; *)
						listeASCourant := [];
						corpsNouvI := sorties ;
						(*listeAvant := contexte;*)
						if entrees <> [] then
						begin
							List.iter (
								fun entree -> 
									match entree with 
									VAR (id, exp) ->
										let nouvar = Printf.sprintf "%s%s_%d" id nomFonc n in
										let idsortie = rechercheAffectVDsListeAS  id affectSortie in
										if idsortie = EXP(NOTHING) then corpsNouvI:= List.append !corpsNouvI [VAR (id, EXP(VARIABLE(nouvar)))]
									
									| MEMASSIGN ( id, _, _)->  ()
									| _ ->   ()
								)entrees;

						end;
						
						
						(*afficherUneAffect (BEGIN(corps)); new_line(); Printf.printf "affect a apere reecrire fin\n";*)
						let memoutput = !corpsNouvI in
						let listeInput =   (evalInputFunction a entrees [] ) in

						(*Printf.printf "INPUT %s depend de var de boucle %s\n" nomFonc varB;
						afficherListeAS listeInput;		*)		
						(*afficherListeAS listeInput;	*)
						
						
						let rc =if (isAbs)  then ( rond listeInput absStore) else evalStore (BEGIN(corps)) (*rond a*) listeInput [] in


						(*Printf.printf "le sortiesRC %s depend de var de boucle fin inputs%s\n" nomFonc varB;
						afficherListeAS rc;
						Printf.printf "fin RC %s depend de var de boucle fin inputs%s\n" nomFonc varB;*)

						listeASCourant := [];
						if memoutput <> [] then
						begin
							(*afficherListeAS rc;*) 
							List.iter (
										fun sortie -> 
										(match sortie with 
											VAR (id, e) ->   
												let (isOkSortie, isnotchange) =  isOkSortie e rc [] id in
												if isnotchange = false then
												if isOkSortie then
													if existAssosArrayIDsize id  then  (getTabAssign sortie rc [] )  
													else listeASCourant :=  List.append  [new_assign_simple id  (getSortie e rc [] id)]  !listeASCourant 
												else listeASCourant :=  List.append  [new_assign_simple id  MULTIPLE]  !listeASCourant; 
												()
											| TAB (id, e1, e2) ->  
												let (isOkSortie, isnotchange) =  isOkSortie e2 rc [] id in
												if isnotchange = false then
													if isOkSortie then  
														(getTabAssign sortie rc [] )  
													else listeASCourant := List.append [ASSIGN_DOUBLE (id, MULTIPLE, MULTIPLE)] !listeASCourant;
												()
											|MEMASSIGN (id, e1, e2)-> 
												let (isOkSortie, isnotchange) =  isOkSortie e2 rc [] id in
												if isnotchange = false then
												if isOkSortie then
													getMemAssign sortie rc []
												else listeASCourant := List.append [ASSIGN_MEM (id,MULTIPLE,   MULTIPLE )] !listeASCourant;
												  ()
											|_->()
										)
								)memoutput	
						end;
						(*let nginterne = filterGlobales rc  !alreadyAffectedGlobales in*)
					 
						let aPart = (splitTotalAndOthers rc !alreadyAffectedGlobales rename)  in
(*Printf.printf "evalStore fonction %s  \n SORTIE \n" nomFonc ;
afficherListeAS aPart;		*)

						let returnf = Printf.sprintf "res-%s"  nomFonc in
						if existeAffectationVarListe returnf rc then
						begin
							let affectres = ro returnf rc in
							listeASCourant :=  List.append [affectres] (List.append (*List.append aPart nginterne*)aPart !listeASCourant )
						end
						else listeASCourant :=   (List.append (*List.append aPart nginterne*)aPart !listeASCourant );



(*Printf.printf "evalStore fonction %s  \n" nomFonc ;*)
(*afficherListeAS rc;		*)	
(*Printf.printf "evalStore fonction %s  \n" nomFonc ;*)(*afficherListeAS !listeASCourant; Printf.printf "fin res\n" ;*)		 

					(*Printf.printf "\nsorties %s depend de var de boucle %s\n" nomFonc varB; afficherListeAS !listeASCourant; Printf.printf "fin sorties\n";*)
						let nc = rond a   !listeASCourant  in

(*if (isAbs)  then Printf.printf "ABSTRACT STORE\n";*)

(*if nomFonc = (*"SelfTestChannel" *)"initOldPotential"   then 
						begin Printf.printf "affect a apere reecrire fin\n";


							(*	*)
							Printf.printf "evalStore fonction dans boucle %s appel %d n\n" nomFonc n;Printf.printf "contxte \n" ; 
							afficherListeAS !listeASCourant;Printf.printf "fin res\n" ;
						end;*)

(*afficherListeAS nc;*)
(*print_string ("Appel fonction definie: FIN "^nomFonc ^"\n");*)
						nc
			(*Printf.printf "evalStore fonction %s  \n global filter" nomFonc ; afficherListeAS nginterne; Printf.printf "fin res\n" ;*)
			(*Printf.printf "evalStore fonction %s  \n" nomFonc ;afficherListeAS !listeASCourant; Printf.printf "fin res\n" ;*)
		end
	end	



and setExtern sorties nom =
listeASCourant := [];
if sorties <> [] then

		List.iter (
						fun sortie -> 
							match sortie with 
									VAR (id, _) -> listeASCourant :=  List.append  [new_assign_simple id  MULTIPLE ]  !listeASCourant; ()
									| TAB (id, _, _) ->   listeASCourant := List.append  [ASSIGN_DOUBLE (id,  MULTIPLE,  MULTIPLE)] !listeASCourant;()
									|MEMASSIGN (id, _, _)->  listeASCourant := List.append [ASSIGN_MEM (id,  MULTIPLE,  MULTIPLE)] !listeASCourant; ()
									|_->()
				)sorties	; 



and getTabAssign sortie a g =

let index = match sortie with VAR(_, _)->CONSTANT(CONST_INT("0"))| TAB (_, e1, _)-> expVaToExp (applyStoreVA (applyStoreVA e1 a)g)|_->NOTHING in
let valindex = ( calculer  (EXP(index))   !infoaffichNull [] 1) in
match sortie with 
		VAR (id, e) | TAB (id, _, e)-> 
  
				(match e with
					EXP(VARIABLE (v))->  
						 let var=	if (String.length v > 1) then if (String.sub v 0 1) = "*" then  String.sub v 1 ((String.length v)-1) else v else v in
						 let listea = rofiltertabandmemonly var a in
						 let listassign = List.map(
									fun aSCourant ->  match aSCourant with ASSIGN_SIMPLE (_, _) -> aSCourant 
											|	ASSIGN_DOUBLE (n, EXP(ei), ee) -> 
													ASSIGN_DOUBLE (id, applyStoreVA (EXP(BINARY(ADD,ei,index))) g, applyStoreVA ee g)
											|	ASSIGN_MEM  (n,ei, ee)	->  
													let indexa =  (applyStoreVA ei  g) in
													let assign = (applyStoreVA ee  g) in
													let (na,_,_,_) = getArrayAssign n indexa assign  in
													(match na with
															ASSIGN_DOUBLE (x, EXP(y), z) ->  ASSIGN_DOUBLE ("*"^id, 
																			EXP(BINARY(ADD,
																						remplacerValPar  var (VARIABLE(id)) y,
																				index)),
																				 z)
														|   ASSIGN_MEM  (x,EXP(y), z) ->
															if estNul valindex 
															then ASSIGN_MEM  ("*"^id,(EXP(remplacerValPar  var (VARIABLE(id)) y)), z) 
															else ASSIGN_MEM  ("*"^id,MULTIPLE, z)
														|  _ -> ASSIGN_DOUBLE ("*"^id, MULTIPLE, MULTIPLE)
													)
											
											|_->ASSIGN_DOUBLE (id, MULTIPLE, MULTIPLE)
										) listea in
						 listeASCourant :=  List.append  listassign  !listeASCourant ;()
					|_->())
						 				
|_->()

and getMemAssign sortie a g =
match sortie with 
		MEMASSIGN (id, e1, e2)->   
			(match e2 with
					(EXP (UNARY(MEMOF, VARIABLE (v))))-> 
			 let var=	if (String.length v > 1) then if (String.sub v 0 1) = "*" then  String.sub v 1 ((String.length v)-1) else v else v in
			let vars=	if (String.length id > 1) then if (String.sub id 0 1) = "*" then  String.sub id 1 ((String.length id)-1) else id else id in
			 let listea = rofiltertabandmemonly var a in
			 let listassign = List.map(
						fun aSCourant ->  match aSCourant with ASSIGN_SIMPLE (_, _) -> aSCourant 
								|	ASSIGN_DOUBLE (n, ei, ee) -> ASSIGN_DOUBLE (vars, applyStoreVA ei g, applyStoreVA ee g)
								|	ASSIGN_MEM  (n, EXP(ei), ee)	->   
									
									 	ASSIGN_MEM (id, applyStoreVA (EXP(remplacerValPar  var (VARIABLE(vars)) ei)) g, applyStoreVA ee g)
								|_->  ASSIGN_MEM (id, MULTIPLE, MULTIPLE)
									
							) listea in
 (*Printf.printf "notchangeSortie %s %s \n" id var;
					afficherListeAS listassign;*)
			 listeASCourant :=  List.append  listassign  !listeASCourant 
		|_->())				 				
|_->()



and rofilteSingleAssign var liste(* first*) =
		List.filter 
		(fun aSCourant ->  match aSCourant with ASSIGN_SIMPLE (id, _) 	->  
	if id = var then  true  else false


|	ASSIGN_DOUBLE (id, _, _) |ASSIGN_MEM (id, _, _)->false ) liste



and isOkSortie  exp a gl id=
match exp with
EXP(VARIABLE (v))| (EXP (UNARY(MEMOF, VARIABLE (v))))->  
let var=	if (String.length v > 1) then if (String.sub v 0 1) = "*" then  String.sub v 1 ((String.length v)-1) else v else v in
let assignvar = rofilteSingleAssign var a in
		let isok =
			if (assignvar = []) then true
			else if (List.tl assignvar = []) then true else (allthesame assignvar)
 
			in
		let notc = notchangeSortie  var a && (existeAffectationVarListe id a = false) in
(*Printf.printf "notchangeSortie %s  \n"var;
if notc = true then Printf.printf "pas d'affect  \n" else Printf.printf "is affected  %s\n" v;
if isok = true then Printf.printf "ok \n" else Printf.printf "nok %s\n" v;*)
(isok, notc)

|_-> (true,true)

and notchangeSortie  var a  =
(*Printf.printf "notchangeSortie %s  \n"var;*)
let res =
	if (existeAffectationVarListe ("*"^var) a ) then 
		false
	else if existassigndouvle var a  then false else true in
(*if res = true then Printf.printf "pas d'affect  \n" else Printf.printf "is affected  \n";*)
res

and containtbinaryOrMulti exp =
match 	exp with MULTIPLE -> true
				| EXP(e)->
					(match e with
						NOTHING -> false
						| UNARY (_, e) ->containtbinaryOrMulti (EXP(e))		 
						| BINARY (_, exp1, exp2) ->true
						| QUESTION (exp1, exp2, exp3) ->
							containtbinaryOrMulti  (EXP(exp1))||containtbinaryOrMulti  (EXP(exp2)) ||containtbinaryOrMulti (EXP(exp3)) ;
						| CAST (_, e) ->containtbinaryOrMulti (EXP(e))
						| CALL (exp, args) ->false (* not possible*)
						| COMMA exps ->false (* not possible*)
						| CONSTANT cst ->false
						| VARIABLE name ->false
						| EXPR_SIZEOF e ->containtbinaryOrMulti (EXP(e))
						| TYPE_SIZEOF typ ->false
						| INDEX (exp, idx) ->false(* not possible*)
						| MEMBEROF (exp, fld) ->false(* not possible*)
						| MEMBEROFPTR (exp, fld) ->false(* not possible*)
						| GNU_BODY (decs, stat) ->false(* not possible*)
						| EXPR_LINE (expr, _, _) ->false(* not possible*))

and getSortie exp a gl id= (* only call when the output value of the function is not change for call like ptr input = &var or &(p.x) or &(t->x) so into funtion
*) 
match exp with
EXP(VARIABLE (v))->  

		let var=	if (String.length v > 1) then if (String.sub v 0 1) = "*" then  String.sub v 1 ((String.length v)-1) else v else v in

			let listea = rofilterandmem var a in

			if (existeAffectationVarListe ("*"^var) listea ) then 
			begin
						let newassign = (ro ("*"^var) listea) in
			
						(match newassign with 
							ASSIGN_SIMPLE  (_,va) -> applyStoreVA (va) gl
							| ASSIGN_MEM (_, xx, va) -> if containtbinaryOrMulti xx then(*print_expVA xx ;*)
								(  MULTIPLE) else applyStoreVA va gl 
							|_->MULTIPLE)
			end
			else  MULTIPLE
|_-> MULTIPLE
	


(*let rx =     if  String.length x > 1 then 
											if (String.sub x  0 1)="*" then 
												(String.sub x 1 ((String.length x)-1) ) 
											else (x )
									else (x ) in  


				let isStruct = if (List.mem_assoc rx !listAssocIdType) then  
							   begin let (isstruct, _) =   isStructAndGetIt (List.assoc rx !listAssocIdType) in  isstruct end 
							   else 
									if List.mem_assoc rx !listeAssosPtrNameType then 
									begin  let (isstruct, _) =   isStructAndGetIt (List.assoc rx !listeAssosPtrNameType) in isstruct 
									end
									else begin  false end in*)
and evalInputFunction a entrees  globales =
	if entrees <> [] then
	begin
		let(entree, others) = (List.hd entrees, List.tl entrees) in
			
		match entree with 
			VAR (id, exp) -> 
				let new_exp =
					(*if   List.mem_assoc id !listAssocIdType then 
								(Printf.printf"evalInputFunction...%s 1\n" id; applyStoreVA (applyStoreVA exp a) globales)
					else  
						if List.mem_assoc id !listeAssosPtrNameType then 
							
						else*)
						(match exp with
							EXP (assign) ->
								let assignedValue = (simplifierValeur assign) in
								

								(match  assignedValue with  
									UNARY (ADDROF, VARIABLE(v)) -> 
										let (typ, hastype,isptr) = if List.mem_assoc v !listAssocIdType then 
																(getBaseType (List.assoc v !listAssocIdType), true,false)
		 										 			 else 
																if List.mem_assoc v !listeAssosPtrNameType then 
																	(getBaseType (List.assoc v !listeAssosPtrNameType),true,true)
																else  (INT_TYPE, false,false)
													 in
										if hastype then listeAssosPtrNameType := List.append !listeAssosPtrNameType [(id, typ)]   ;
 
										 applyStoreVA (applyStoreVA exp a) globales
								
									| VARIABLE(v)->	
										let (typ, hastype,isptr) = if List.mem_assoc v !listAssocIdType then 
																(getBaseType (List.assoc v !listAssocIdType), true,false)
		 										 			 else 
																if List.mem_assoc v !listeAssosPtrNameType then 
																	(getBaseType (List.assoc v !listeAssosPtrNameType),true, true)
																else  (INT_TYPE, false,false)
													 in
 
										if hastype then 
										begin
												if isptr then
														listeAssosPtrNameType := List.append !listeAssosPtrNameType [(id, typ)] 
												else listAssocIdType := List.append !listAssocIdType [(id, typ)]   
										end;

										if isptr ||List.mem_assoc id !listeAssosPtrNameType  then 
											if existeAffectationVarListe ("*"^v) a || existeAffectationVarListe ("*"^v) globales then
												applyStoreVA (applyStoreVA (EXP(UNARY (ADDROF,(VARIABLE("*"^v))))) a) globales
											else  applyStoreVA (applyStoreVA exp a) globales
										else  applyStoreVA (applyStoreVA exp a) globales
									|_-> applyStoreVA (applyStoreVA exp a) globales  )


							|_-> applyStoreVA (applyStoreVA exp a) globales ) in


					
					 
					List.append   [new_assign_simple id  new_exp]  (evalInputFunction a others globales)
				
				| MEMASSIGN ( id, _, _)->   (evalInputFunction a others globales)	
				| TAB (id, e1, e2)->    (evalInputFunction a others globales)
				|_-> (evalInputFunction a others globales)
	end	
	else []





and  traiterSequence liste a g =
if liste = [] then a
else traiterSequence (List.tl liste) (evalStore (List.hd liste) a g) g														

and closeFormPourToutXdelisteES l id  =
	(*Printf.printf "closeFormPourToutXdelisteES %s fin\n" id; *)
	let listeDesVarModifiees = (rechercheLesVar l [] ) in
	listeDesCloseChanged := [];
	let (listeres, others) =  (closeFormrec id  listeDesVarModifiees l listeDesVarModifiees) in
	let (filteredOthers, rewritedOthers) = (othersFilter others,rewriteAllOthers others ) in
	let (after,before) = filterGlobalesAndOthers listeres   !listeDesCloseChanged in
	let nl = (traiterOthers (List.append before after) filteredOthers rewritedOthers) in
(*Printf.printf "\nl\n";
	afficherListeAS nl ;space();flush();new_line();
	Printf.printf "\nend\n";*)


	(*Printf.printf "\nlisteres\n";
	afficherListeAS listeres ;space();flush();new_line();
	Printf.printf "\nend\n";
	(*Printf.printf "\nothers rewriteAllOthers\n";
	afficherListeAS (rewriteAllOthers others);space();flush();new_line();
	Printf.printf "\nend\n";*)
	Printf.printf "others\n";
	afficherListeAS others ;space();flush();new_line();
	Printf.printf "\nend\n";*)

	(*Printf.printf "\nothers traites\n";
	afficherListeAS nl;space();flush();new_line();*)
	let fineval = (traiterAntidepPointFixe id nl ) in
	(*Printf.printf "\npoint fixe\n";
	afficherListeAS fineval;space();flush();new_line();
	Printf.printf "\npoint fixe\n";*)
	(fineval, filteredOthers, rewritedOthers)




and traiterOthers asl  others newothers =
if others = [] || asl = [] || newothers = [] then asl 
else 
begin
	
	let nasl = asl in

	let (first, next) = (List.hd others, List.tl others) in
	let (firstChange, nextchanges) = ([List.hd newothers], List.tl newothers) in
	let (before, after) = roavant  nasl first [] in
(*afficherListeAS before;space();flush();new_line();
Printf.printf "\nactual\n";
afficherAS first;space();flush();new_line();
Printf.printf "\nafter\n";
afficherListeAS after;space();flush();new_line();
Printf.printf "\nend\n";*)
	let na = applynewothers before firstChange in
	let nl =  (traiterOthers (List.append na(List.append [first] after)) next nextchanges)  in

(*Printf.printf "\traiterOthers\n";
afficherListeAS nl;space();flush();new_line();
Printf.printf "\traiterOthers\n";*)

	 nl 
end
and applynewothers before firstChange=
	List.map(fun asc ->  
				
				match asc with
					ASSIGN_SIMPLE (id, e)->     
						let na = ASSIGN_SIMPLE (id,    applyStoreVA  e firstChange) in
						if na != asc then
						begin
							if (String.length id > 4) then
							begin
									let var3 = (String.sub id  0 3) in
									if  var3 = "IF-"|| var3 = "ET-" ||  var3 = "EF-"  then  asc else na
							end
							else na
						end else na								
				|   ASSIGN_DOUBLE (id,e1,e2)-> ASSIGN_DOUBLE (id,applyStoreVA  e1 firstChange ,  applyStoreVA  e2 firstChange   )
				|   ASSIGN_MEM (id, e1, e2) -> ASSIGN_MEM (id,applyStoreVA  e1 firstChange ,  applyStoreVA  e2 firstChange  )
	 
			) before

and rewriteAllOthers others =
if others = [] then [] else List.append (rewriteOthers (List.hd others)) (rewriteAllOthers (List.tl others))

and othersFilter others =
List.filter (fun assign->
match assign with
		ASSIGN_SIMPLE (id, e)->    		
		if (String.length id > 4) then
		begin
			let var4 = (String.sub id  0 4) in
			let var3 = (String.sub id  0 3) in
			if  var3 = "IF-" || var3 = "ET-" ||  var3 = "EF-" || var3 = "tN-" || var4 = "max-" || var4 = "tni-" || var4 = "TWH-" then false else true
		end
		else if (String.length id > 3) then 
					if (String.sub id  0 3) = "IF-" || (String.sub id  0 3) = "ET-" ||  (String.sub id  0 3) = "EF-" || (String.sub id  0 3) = "tN-" then false else true
					else true	
	|  _-> true
) others

and rewriteOthers assign = 
match assign with
		ASSIGN_SIMPLE (id, e)->    

(* changestruct*)

		let na = ASSIGN_SIMPLE (id,    EXP(CALL (VARIABLE("SET") , List.append [VARIABLE(id)] [expVaToExp e])))  in
		if (String.length id > 4) then
		begin
			let var4 = (String.sub id  0 4) in
			let var3 = (String.sub id  0 3) in
			if  var3 = "IF-" || var3 = "ET-" ||  var3 = "EF-" || var3 = "tN-" || var4 = "max-" || var4 = "tni-" || var4 = "TWH-" then [] else [na]
		end
		else if (String.length id > 3) then 
					if (String.sub id  0 3) = "IF-"  || (String.sub id  0 3) = "ET-" ||  (String.sub id  0 3) = "EF-" || (String.sub id  0 3) = "tN-"  then [] else [na]
					else [na]
		
			
	|   ASSIGN_DOUBLE (id,e1,e2)-> [ASSIGN_DOUBLE (id,e1, MULTIPLE)
										(*EXP(CALL (VARIABLE("SET") , 
											List.append [INDEX(VARIABLE(id), expVaToExp e1)] 
											[expVaToExp e2])) )*)]
	|   ASSIGN_MEM (id, e1, e2) -> [ASSIGN_MEM (id, e1, MULTIPLE)
										(*EXP(CALL (VARIABLE("SET") , 
											List.append [UNARY(MEMOF, BINARY(ADD,VARIABLE(id), expVaToExp e1))]

											[expVaToExp e2])) )*)]




and closeFormrec id  l listeaS listeDesVarModifiees =
(*Printf.printf "closeFormrec %s \n" id;*)
if (listeaS = []) then begin (*Printf.printf "FIN closeFormrec %s \n" id; *) ([], [])end
else 
	begin
		let aSCourant = List.hd listeaS in

		let suite = List.tl listeaS in

		let (predna, new_affect, otherAffect) =  closeForm aSCourant  id listeDesVarModifiees 	in

		let (nextAffect, othersNext) = closeFormrec id l suite listeDesVarModifiees  in
(*Printf.printf "otherAffect\n";

afficherListeAS otherAffect;new_line();
Printf.printf "suite\n";
afficherListeAS othersNext;new_line();*)

		(List.append [new_affect] nextAffect, List.append     otherAffect othersNext)
end

and traiterAntidepPointFixe id listeAffect =
(* Printf.printf "traiterAntidepPointFixe\n" ;*)
	if !listeDesVarDependITitcour = [] then
	begin
		(*Printf.printf "traiterAntidepPointFixe FIN :  liste res :\n";
		afficherListeAS listeAffect;
		Printf.printf "traiterAntidepPointFixe : fin liste res :\n";   *)
		listeAffect
	end
	else
	begin (*Printf.printf "poursuivre point fixe\n" ;*)

(*Printf.printf "traiterAntidepPointFixe : liste des variables modifiées :\n";
afficherListeAS !listeDesVarDependITitcour;
Printf.printf "traiterAntidepPointFixe : fin liste des variables modifiées :\n";
Printf.printf "AVANT TRAITER ANTI DEP\n";*)
		let liste = !listeDesVarDependITitcour in
		listeDesVarDependITitcour := [];

(*Printf.printf "traiterAntidepPointFixe : liste des variables modifiées :\n";
afficherListeAS liste;*)

		let res = traiterAntidep id listeAffect liste  in

(*Printf.printf "traiterAntidepPointFixe :  liste res :\n";
afficherListeAS res;
Printf.printf "traiterAntidepPointFixe : fin liste res :\n";*)
		traiterAntidepPointFixe id res   
	end 

and  traiterAntidep id listeAffect listeAffectP =
(*Printf.printf "traiterAntidep \n";*)
if listeAffect = [] then []
else
begin
	if listeAffectP = [] then listeAffect
	else
		begin
			let listeaffectEtape = listeAffectP in
			let listeDesnewAffect = List.map (fun a -> remplacer id a) listeAffectP in

(*Printf.printf "traiterAntidep : liste des variables modifiées :\n";
afficherListeAS listeDesnewAffect;
Printf.printf "traiterAntidep : fin liste des variables modifiées :\n";*)
			remplacerToutes listeDesnewAffect listeAffect listeaffectEtape 		
		end
end




and  listeAffectBegin liste affect = (* liste affect pred *)
if liste = [] then ([], [])
else
begin
	let (a, suite) = (List.hd liste, List.tl liste) in
	if a = affect then ([] , suite)
	else 
	begin
		let (deb, fin) = (listeAffectBegin suite affect) in
		(List.append  deb [a], fin)
	end
end

and remplacerUneAffect assign aSC =
let listeDesVarModifiees = (rechercheLesVar aSC [] ) in

(*Printf.printf " remplacer remplacerUneAffect \n";afficherAS assign;new_line();*)
match assign with
	ASSIGN_SIMPLE (id, e)->	 	
		(match e with 
			MULTIPLE -> assign
			| EXP (exp) ->  
			if ( intersection (listeDesVarsDeExpSeules exp)  listeDesVarModifiees  ) != [] then  
				new_assign_simple id  (applyStoreVA e aSC) 
			else assign)
	| ASSIGN_DOUBLE (id,e1,e2) ->  
	(match e1 with 
			MULTIPLE -> assign
			| EXP (exp) -> 
			if ( intersection (listeDesVarsDeExpSeules exp)  listeDesVarModifiees  ) != [] then 
			begin 
				(match e2 with 
					MULTIPLE -> assign
					| EXP (exp2) -> 
					if ( intersection (listeDesVarsDeExpSeules exp2)  listeDesVarModifiees ) != []then  
						ASSIGN_DOUBLE (id,  applyStoreVA e1 aSC, applyStoreVA e2 aSC) 
					else assign)
			end 
			else assign)
	| ASSIGN_MEM (id,e1,e2) ->  
	(match e1 with 
			MULTIPLE -> assign
			| EXP (exp) -> 
			if ( intersection (listeDesVarsDeExpSeules exp)  listeDesVarModifiees  ) != [] then 
			begin 
				(match e2 with 
					MULTIPLE -> assign
					| EXP (exp2) -> 
					if ( intersection (listeDesVarsDeExpSeules exp2)  listeDesVarModifiees ) != []then  
						ASSIGN_MEM (id,  applyStoreVA e1 aSC, applyStoreVA e2 aSC) 
					else assign)
			end 
			else assign)


and remplacerToutes reverseliste l listeaffectEtape 	=
(*Printf.printf "remplacer toutes\n";
Printf.printf "liste affect etape \n";
afficherListeAS listeaffectEtape;
Printf.printf "remplacerToutesAffect fin liste l\n" ;*)
if listeaffectEtape = [] then begin  (*Printf.printf "liste affect etape vide\n";*)l end
else
begin
	let derniereAffectCour = List.hd listeaffectEtape in
	(*let aa = List.hd reverseliste in*)
	let (ltete , suite ) = listeAffectBegin l derniereAffectCour in
	let (teteaux , suiteaux) =(List.rev ltete, List.rev  suite) in


(*Printf.printf "remplacerToutesAffect precedentes\n" ;
afficherListeAS teteaux;
Printf.printf "remplacerToutesAffect fin liste\nAffectation courante :\n" ;
afficherAS derniereAffectCour;

Printf.printf "\nremplacerToutesAffect suite\n" ;
afficherListeAS suiteaux;
Printf.printf "\nremplacerToutesAffect fin liste\n" ;*)

	if teteaux = [] then (*if !estDansBoucleLast then (rond [derniereAffectCour] (remplacerToutes (List.tl reverseliste)  suite (List.tl listeaffectEtape)))
						 else*) (List.append [derniereAffectCour] (remplacerToutes (List.tl reverseliste)  suite (List.tl listeaffectEtape)))
	(* rond is absolutly necessary at the last step*)
	else
	begin
		let new_tete =  List.map
				(fun a ->(*afficherAS a;*)
					let na = remplacerUneAffect a reverseliste in
						 if a != na then  
						begin
						(*	Printf.printf "a != na\n";*)
(*Printf.printf "maj liste dep it cou\n" ;
afficherAS na;
Printf.printf "remplacerUneAffect nouveau assign fin\n" ;*)
						(*afficherAS na;*)
						listeDesVarDependITitcour := List.append !listeDesVarDependITitcour [na]
						end;
						 na
				) teteaux in



let ressuite = remplacerToutes (List.tl reverseliste)  suite (List.tl listeaffectEtape) in

(*Printf.printf "remplacerToutesAffect l :\n" ;
afficherListeAS l;
Printf.printf "remplacerToutesAffect fin liste l\n" ;*)
(*
Printf.printf "remplacerToutesAffect res\n";
Printf.printf "tete\n";
afficherListeAS ( new_tete);
Printf.printf "cour\n";
afficherAS derniereAffectCour;
Printf.printf "suite\n";
afficherListeAS ( ressuite);
Printf.printf "remplacerToutesAffect res\n" ;*)

(* faire les rond que si pas de boucle au dessus pour écraser l'erreur sinon faire un list append*)
	List.append ( new_tete)  (List.append  [derniereAffectCour] ressuite)
 	end 
end

let applyif exp a =
(*Printf.printf "applyif \n";*)
if a =[] || exp = MULTIPLE then exp
else
begin
	let varOfExp1 = listeDesVarsDeExpSeules (expVaToExp exp) in
	let na = List.filter (fun ass -> match ass with ASSIGN_SIMPLE (id, _)  |	ASSIGN_DOUBLE (id, _, _)  |ASSIGN_MEM (id, _, _)	-> 
					 if List.mem id  varOfExp1 && listVARMAXSYG id (expVaToExp exp) then false else true  ) a in
	applyStoreVA exp na
end

let rec extractVarCONDAffectaux  listeAffect listeCondVar =
if listeAffect = [] then ([], [])
else 
begin
	let (affect, suite) = (List.hd listeAffect, List.tl listeAffect) in

	let (newSuite, listeaux) = extractVarCONDAffectaux suite listeCondVar in

	match affect with
	 VAR ( id, exp) 				->	 
		if  List.mem id listeCondVar then 
		begin 
			(List.append [affect] newSuite, union  listeaux (listeDesVarsDeExpSeules  (expVaToExp (exp)))) 
		end 
		else (newSuite, listeaux) 
	| TAB ( id, _, _) 	->  (newSuite, listeaux)
	|  MEMASSIGN ( id, _, _)	->  (newSuite, listeaux) (*voir*)
	| IFVF ( expVA1, i1, i2) 		->
			let (newi1, listeaux1) = extractVarCONDAffectaux [i1] listeCondVar in
			let (newi2, listeaux2)  = extractVarCONDAffectaux [i2] listeCondVar in
			if newi1 = [] && newi2 = [] then (newSuite, listeaux)
			else 
			begin
				let next1 = if newi1 = [] then BEGIN([]) else List.hd newi1 in
				let next2 = if newi2 = [] then BEGIN([]) else List.hd newi2 in
				let unionOfAll = match  expVA1 with EXP(VARIABLE(varIfN)) ->
								 union [varIfN] (union (union listeaux1 listeaux2) listeaux)|_-> union (union listeaux1 listeaux2) listeaux  in
				(List.append [IFVF ( expVA1, next1, next2) ] newSuite, unionOfAll)
			end
	| IFV ( expVA1, i1) 		->
			let (newi1, listeaux1) = extractVarCONDAffectaux [i1] listeCondVar in
			
			if newi1 = []  then (newSuite, listeaux)
			else
				(
						let unionOfAll = match  expVA1 with EXP(VARIABLE(varIfN)) -> union [varIfN] (union listeaux1 listeaux)|_-> union listeaux1 listeaux in
						(List.append [IFV ( expVA1, List.hd newi1)] newSuite, unionOfAll)
				)
	| BEGIN (liste)			->  
			let (newi1, listeaux1) = extractVarCONDAffectaux liste listeCondVar in		
			if newi1 = []  then (newSuite, listeaux)
			else (List.append [BEGIN ( newi1)] newSuite, union listeaux1 listeaux)			
	| FORV ( num, id, expVA1, expVA2, expVA3, n, i) -> 	
			let (newi1, listeaux1) = extractVarCONDAffectaux [i] listeCondVar in		
			if newi1 = []  then (newSuite, listeaux)
			else (List.append [  FORV ( num, id, expVA1, expVA2, expVA3, n, (List.hd newi1))] newSuite, union listeaux1 listeaux)				

	| APPEL (num, e, nom, s, CORPS c,v,r) ->
			(* var may be a global *)
if List.mem_assoc  nom !alreadyEvalFunctionAS = false then
begin
			let (newi1, listeaux1) = extractVarCONDAffectaux [c] listeCondVar in
			if newi1 = []  then (newSuite, listeaux)
			else (List.append [ APPEL( num, e,nom ,s, CORPS (List.hd newi1),v,r)] newSuite, union  listeaux1 listeaux)			
end 
else
begin
			let a = List.assoc nom !alreadyEvalFunctionAS  in
		                let c = BEGIN (listeAsToListeAffect a) in
			(* var may be a global *)
			let (newi1, listeaux1) = extractVarCONDAffectaux [c] listeCondVar in
			if newi1 = []  then (newSuite, listeaux)
			
			else
			begin
				 let na = evalStore (List.hd newi1) [] [] in
				 (List.append [ APPEL( num, e,nom ,s, ABSSTORE na,v,r)] newSuite, union  listeaux1 listeaux)	
			end	
end	

	| APPEL (num, e, nom, s, ABSSTORE a,v,r) ->
	                let c = BEGIN (listeAsToListeAffect a) in
			(* var may be a global *)
			let (newi1, listeaux1) = extractVarCONDAffectaux [c] listeCondVar in
			if newi1 = []  then (newSuite, listeaux)
			
			else
			begin
				 let na = evalStore (List.hd newi1) [] [] in
				 (List.append [ APPEL( num, e,nom ,s, ABSSTORE na,v,r)] newSuite, union  listeaux1 listeaux)	
			end			
end

(* fixed point operator to find any usefull variable for loop condition*)
let rec extractVarCONDAffect listeAffect listeCondVar =
let (extractsInst, listevar) = extractVarCONDAffectaux  listeAffect listeCondVar in
if listevar = [] || (inclus listevar listeCondVar) then extractsInst
else extractVarCONDAffect listeAffect (union listeCondVar listevar)


