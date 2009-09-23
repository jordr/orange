open Cabs
open Frontc

let version = "increment.ml Marianne de Michiel"
(* rename -- use Frontc CAML  a variable name must be used only once -> rename
**
** Project:	O_Range
** File:	increment.ml
** Version:	1.1
** Date:	11.7.2008
** Author:	Marianne de Michiel
*)

open Cprint
open Cexptostr
open Cvarabs
open Cvariables
open Constante


type typeEQ =	INCVIDE (*0 pour + ou -, 1 pour * ou div*)|   NEG|   POS|   NDEF|NOVALID
type typeVAL =	INTEGERV |   FLOATV|   INDEFINEDV

let opEstPlus = ref true
let estPosInc = ref   INCVIDE (*1 positif 0 nul -1 négatif ou diff si incrément *//*)
let expressionIncFor = ref NOTHING

let isMultiInc = ref false
	let listAssosExactLoopInit = ref [(-1, 0)]
	let existAssosExactLoopInit  name  = (List.mem_assoc name !listAssosExactLoopInit)
	let setAssosExactLoopInit  name t =  
		if existAssosExactLoopInit  name = false then
		begin
			let val1 = calculer (EXP t) !infoaffichNull  []  1 in 
			if estNoComp val1  =false then 
 				if estDefExp val1 then
					match val1 with 
					ConstInt(j) -> 		 listAssosExactLoopInit :=  List.append [(name, int_of_string  j)] !listAssosExactLoopInit 	
					|_->()
		end
				
	
	
	let getAssosExactLoopInit name  = (List.assoc name !listAssosExactLoopInit)

type increaseType = POSITIV|NEGATIV|MULTI|DIVI|NOTYPE (* +,-,*or/, NODEF*)
type increaseValue = NOINC|NODEFINC| INC of increaseType * expression


let print_intType t =
match t with
	POSITIV->Printf.printf"POSITIV\n" |NEGATIV->Printf.printf"NEGATIV\n" |MULTI->Printf.printf"MULTI\n" 
 |DIVI->Printf.printf"DIVI\n"|NOTYPE ->Printf.printf"NOTYPE\n" (* +,-,*or/, NODEF*)




let getIncValue inc =
match inc with
	INC(_,v)->v
	|_->NOTHING

let getIncType inc =
match inc with
	INC(t,_)->t
	|_->NOTYPE


let getIstMulInc inc =
match inc with
	INC(MULTI,_)|INC(DIVI,_)->true
	|_->false

let getIsAddInc inc =
match inc with
	INC(MULTI,_)|INC(DIVI,_) ->false
	|_->true


let rec containtMINIMUMCALL exp =
match exp with
		NOTHING -> false
		| UNARY (_, e1) -> containtMINIMUMCALL e1
		| BINARY (_, e1, e2) ->containtMINIMUMCALL e1 || containtMINIMUMCALL e2
		| CALL (exp, args) ->
			(match exp with VARIABLE("MINIMUM") -> true|_-> false)
		| _  ->false


let getIsMultipleIncrement incValue =
match incValue with
NOTHING -> false
| exp-> containtMINIMUMCALL exp




let rec rechercheInc var exp =
	let val1 = calculer (EXP exp) !infoaffichNull [] 1 in 
	if val1 = NOCOMP  then NOTHING
	else
	begin
		if (estVarDsExpEval var val1 = false)  then (*exp*) NOTHING
		else
		begin
			if (estAffine var val1)   then 
			begin
				let (a,b) = calculaetbAffineForne var val1 in	
				let (var1, var2) = (evalexpression a , evalexpression b) in
				(*Printf.printf"rechercheInc affine\n"; 
print_expression exp 0;new_line(); flush();new_line(); flush();new_line(); flush();new_line(); flush();space();new_line(); flush();new_line(); flush();space();
print_expTerm val1  ;new_line(); flush();new_line(); flush();new_line(); flush();new_line(); flush();space();new_line(); flush();new_line(); flush();space();
print_expTerm var1  ;new_line(); flush();new_line(); flush();new_line(); flush();new_line(); flush();space();new_line(); flush();new_line(); flush();space();
print_expTerm var2  ;new_line(); flush();new_line(); flush();new_line(); flush();new_line(); flush();space();new_line(); flush();new_line(); flush();space();*)
				if  (estNul var1 = true) || var1 = ConstInt("1") || var1 =  ConstFloat("1.0")||var1 =  RConstFloat(1.0)  then
				begin 
					opEstPlus := true ; 

					if estNul var2 then	estPosInc := INCVIDE 
					else 	if estPositif var2 then estPosInc := POS 
							else if estDefExp  var2 then estPosInc := NEG else estPosInc := NDEF;
					expressionEvalueeToExpression var2  
				end	
				else 
					if (estNul var2) then 
					begin   
						let val1 = expressionEvalueeToExpression var1 in

(*

print_expression val1  0;new_line(); flush();new_line(); flush();new_line(); flush();new_line(); flush();space();new_line(); flush();new_line(); flush();space();*)

						opEstPlus := false ; (*Printf.printf"rechercheInc affine var1 struct pos et val2  nul\n"; *)
						let varMoinsUn = (evalexpression (Diff( var1,  ConstInt("1")))) in
						if estStricPositif var1 then
						begin (*Printf.printf"rechercheInc affine test de var1 - 1 \n"; *)
							if estNul varMoinsUn then	begin estPosInc := INCVIDE; val1 end
							else  
							begin
								estPosInc := POS ;	(*Printf.printf"div or mult inc\n"; *)
								if estStricPositif varMoinsUn then val1
								else begin estPosInc := NEG ;(*Printf.printf"div inc\n"; *)(* BINARY (DIV, CONSTANT  (CONST_INT "1"),*) val1(* ) *) end
							end
						end
						else 
						begin
							estPosInc := NDEF;(*Printf.printf"rechercheInc affine var1 struct pos et val2 non nul\n"; *)
							expressionEvalueeToExpression var1 
						end
					end
					else NOTHING		
			end
			else NOTHING
		end
	end 

let rec analyseIncFor var exp inst las asAs completList=
(*Printf.printf "analyse inc de %s \n" var ;
print_expression exp 0; new_line(); flush();*)
(	match exp with	
	BINARY (op, exp1, exp2) ->
		(	match exp1 with
			VARIABLE (v) -> 
				if v = var then
				begin
				(	match op with
					ASSIGN ->  (*	print_expression exp2 0; new_line(); flush();*)
						if List.mem var (listeDesVarsDeExpSeules  exp2) =false  then
						begin
					(* si j=i+N avec i mofifiée par la boucle alors on peut remplacer la condition sur j dans le test de boucle par une condition sur i+N sans décalage pour un do while mais avec décalage pour les autres boucles*)							
							let (inc, before, isAddinc, isComp, varDep) = getIndirectIncrease var exp2 inst las asAs completList in
							if isComp then
							begin
							(*	Printf.printf "%s depend indirectement de %s \n" var varDep;
								if inc = NOTHING then Printf.printf "no  inc\n" else print_expression inc 0; new_line();flush();
								if before then Printf.printf "before\n" else Printf.printf "next\n";
								if isAddinc then Printf.printf "adding inc\n" else Printf.printf "prodinc\n";*)
								(inc, before, isAddinc,true,varDep)(*(NOTHING, true, true,false,var)*)
							end
							else begin (* Printf.printf "nocomp indirect\n" ; *)
												(NOTHING, before, isAddinc,false,var) end
						end
						else 
						begin 
									(*Printf.printf "recherche incremet %s\n" var;*)
							expressionIncFor:= rechercheInc var exp2	;(* print_expression !expressionIncFor 0; new_line();flush();*)
							(!expressionIncFor, true, !opEstPlus,(!expressionIncFor != NOTHING),var)			
						end			

					| ADD_ASSIGN ->  (exp2, true, true, true, var)
					| SUB_ASSIGN ->  (UNARY (MINUS, exp2),true, true, true, var)
					| MUL_ASSIGN ->  (exp2,true,  false,true, var)
					| DIV_ASSIGN ->  (BINARY (DIV, CONSTANT  (CONST_INT "1"), exp2),true,  false,true, var)

							(*| MOD_ASSIGN ->    expressionIncFor := BINARY (MOD, exp1, exp2)*)
					| SHL_ASSIGN ->  (BINARY (MUL, CONSTANT  (CONST_INT "2"), exp2),true,  false,true, var)
					| SHR_ASSIGN ->  (BINARY(DIV,CONSTANT(CONST_INT "1"),BINARY(MUL,CONSTANT(CONST_INT "2"),exp2)),true,false,true,var)
					|_ ->  (NOTHING, true, true,false,var)
				)
				end
				else  (NOTHING, true, true,false,var)
			|_->if List.mem var (listeDesVarsDeExpSeules  exp1) =false   then	analyseIncFor var exp2 inst las asAs completList
				else if List.mem var (listeDesVarsDeExpSeules  exp2) =false  then	analyseIncFor var exp1 inst las asAs completList
					 else (NOTHING, true, true,false,var)
		)
		| UNARY (op, exp1) ->
			(match exp1 with
				VARIABLE (v) -> 
					if v = var then
					begin
						(match op with
						  PREINCR | POSINCR -> (CONSTANT (CONST_INT "1"), true, true, true, var)
						| PREDECR | POSDECR -> (CONSTANT(CONST_INT "-1"), true, true, true, var)
						|_ -> 		(NOTHING, true, true,false,var)
						)
					end
					else   (NOTHING, true, true,false,var)
				|_->  (NOTHING, true, true,false,var)
			)
		| COMMA exps ->	
			if List.mem var (listeDesVarsDeExpSeules exp) =false then	(NOTHING, true, true,false,var)
			else applyComma  exps var exps inst las asAs completList			
								   			
		|_-> (NOTHING, true, true,false,var)
)
and applyComma  exps var ex inst las asAs completList =
if exps = [] then (NOTHING, true, true,false,var) 
else
begin
	let (head, others) = (List.hd exps, List.tl exps) in
	if List.mem var  (listeDesVarsDeExpSeules head) = true then  analyseIncFor var head inst las asAs completList
	else applyComma  others var ex inst las asAs completList
end

and rechercheAffectVDsListeASAndWhere v var l isbefore=
if l = [] then (NOTHING, true)
else 
let a = List.hd l in
let suite = List.tl l in
	match a with
		ASSIGN_SIMPLE (s, e) 	 -> 	if s = v then (expVaToExp(e), isbefore) 
										else 
											if s = var then rechercheAffectVDsListeASAndWhere v var suite true
											else rechercheAffectVDsListeASAndWhere v var suite isbefore
	|	ASSIGN_DOUBLE (s,e1, e2) -> 	
			if s = v (*and il faut évaluer les 2 expression index = e1*) then 
			begin
				if !vDEBUG then begin	Printf.printf "tableau avec index à terminer\n";(* afficherAS a *) end; 
				(expVaToExp(e2), isbefore) 
			end
			else  if s = var then rechercheAffectVDsListeASAndWhere v var suite true
				  else rechercheAffectVDsListeASAndWhere v var suite isbefore
	|	ASSIGN_MEM (s,e1, e2) -> 	
			if s = v (*and il faut évaluer les 2 expression index = e1*) then 
			begin
				if !vDEBUG then begin	Printf.printf "tableau avec index à terminer\n";(* afficherAS a *) end; 
				(expVaToExp(e2), isbefore) 
			end
			else  if s = var then rechercheAffectVDsListeASAndWhere v var suite true
				  else rechercheAffectVDsListeASAndWhere v var suite isbefore



and getIndirectIncrease var exp inst las asAs completList =
(*afficherLesAffectations completList;*)
	if listeDesVarsDeExpSeules  exp  = []  then 
	begin
		(* BOOL en fait de la forme var = cte si cette affectation est gardée par une condition de if alors peut être éventuellement traité *)
	(*	print_expression exp 0; new_line(); flush();
		Printf.printf "Dans increment.ml getIndirectIncrease : it may be a boolean condition non encore traité\n";*)
		(NOTHING, true,true,false,"other")
	end
	else
	 match exp with
		VARIABLE (v) -> 
			
			let cas =evalStore (new_instBEGIN(completList)) [] [] in
			let assignj = expVaToExp(rechercheAffectVDsListeAS var cas) in
						
			(match assignj with
				VARIABLE (x)-> 
					if x = v then
					begin
						opEstPlus:= true;
						let (assign,after)= rechercheAffectVDsListeASAndWhere v var cas false in	
						let (inc, before, isplus,iscomp,nvar)=
								analyseIncFor v (BINARY(ASSIGN,VARIABLE(v),assign)) inst cas true completList in
						if nvar = v then ( inc,after=false, isplus,  (inc != NOTHING), v) else (NOTHING, true,true,false,"other")
					end
					else (NOTHING, true,true,false,"other")
				| NOTHING -> (NOTHING, true,true,false,"other")
				|_-> 		 		
					opEstPlus:= true;
					let (assign,after)= rechercheAffectVDsListeASAndWhere v var cas false in
					if  assign =  assignj then
					begin	
						let (inc, before, isplus,iscomp,nvar)=
							analyseIncFor v (BINARY(ASSIGN,VARIABLE(v),assign)) inst cas true completList in
						if nvar = v then ( inc,after=false, isplus,  (inc != NOTHING), v) else (NOTHING, true,true,false,"other")
					end
					else (NOTHING, true,true,false,"other") )
(* more than one dependancy on can be before the other after... to see*)
				|_->
					if !vDEBUG then Printf.printf "depend d'une expression contenant une autre variable est pas de cette variable seule non encore traité\n";
					(NOTHING, true,true,false,"other")
	 	
and getInc var assign inst las asAs completList=
		opEstPlus:= true;	
		let (inc, before, isplus,iscomp,nvar)= analyseIncFor var (BINARY(ASSIGN,VARIABLE(var),assign)) inst las asAs completList in
		let valinc = calculer (applyStoreVA   (EXP(inc)) [])  !infoaffichNull  [](*appel*) 1 in	

(*print_expTerm	valinc ;*) 
		let isIndirect = nvar != var in
		if estNoComp valinc then (* si aucun increment alors peut être condition var bool*)(false,NODEFINC,"others", before) 
		else
		begin 
			if isplus (*op +or -*) then 
				if estNul valinc then (false,NOINC,"others", before)  
				else if estStricPositif valinc then (isIndirect,INC(POSITIV, expressionEvalueeToExpression valinc),nvar, before)  
					else  (isIndirect,INC(NEGATIV, expressionEvalueeToExpression valinc),nvar, before)
			else (* or / if estStricPositif valinc then *)
			begin
				(*Printf.printf"isIndirect MUORDI\n";*)
				

				let varMoinsUn = (evalexpression (Diff( valinc,  ConstInt("1")))) in
				if estStricPositif valinc then
				begin
					if estNul varMoinsUn then (false,NOINC,"others", before)  
					else   	if estStricPositif varMoinsUn then 
							begin
									(*Printf.printf"isIndirect MULTI\n";*)(isIndirect, INC(MULTI, inc),nvar, before) 
							end
							else 
							begin
								(*Printf.printf"isIndirect DIVI\n";*) (isIndirect, INC(DIVI, inc),nvar, before) 
							end
				end
				else (false,NODEFINC,"others", before) 
				 (*else NODEFINC*)
			end
		end
			

and joinSequence x inc1 inc2 =
match inc1 with 
	INC(POSITIV,v1)->
   			(match inc2 with INC(POSITIV,v2) -> INC(POSITIV,(BINARY(ADD,v1,v2)))
							| INC(NEGATIV,v2) -> 
								let v1Moinsv2 = calculer  (EXP(BINARY(SUB, v1,  v2))) !infoaffichNull [] 1 in
								if estStricPositif v1Moinsv2 then INC(POSITIV,(BINARY(SUB,v1,v2)))
								else
									if estNul v1Moinsv2 then	NOINC
									else  INC(NEGATIV,(BINARY(SUB,v1,v2)))
								
							| NOINC -> inc1
							|_->NODEFINC)
	| INC(NEGATIV,v1) ->
		 (	match inc2 with INC(NEGATIV,v2) -> INC(NEGATIV,(BINARY(ADD,v1,v2)))
							| INC(POSITIV,v2) -> 
								let v1Moinsv2 = calculer  (EXP(BINARY(SUB, v1,  v2))) !infoaffichNull [] 1 in
								if estStricPositif v1Moinsv2 then INC(POSITIV,(BINARY(SUB,v2,v1)))
								else
									if estNul v1Moinsv2 then	NOINC
									else  INC(NEGATIV,(BINARY(SUB,v2,v1)))
							| NOINC -> inc1
							|_->NODEFINC)
	| NOINC -> inc2
	| NODEFINC -> NODEFINC
	| INC(MULTI,v1)->
   			(match inc2 with INC(MULTI,v2) -> INC(MULTI,(BINARY(MUL,v1,v2)))
							| INC(DIVI,v2) -> 
								let v1Divv2 = calculer  (EXP(BINARY(DIV, v1,  v2))) !infoaffichNull [] 1 in
								let varMoinsUn = (evalexpression (Diff( v1Divv2,  ConstInt("1")))) in
								if estStricPositif v1Divv2 then
								begin
									if estNul varMoinsUn then  NOINC 
									else   if estStricPositif varMoinsUn then   INC(MULTI, (BINARY(DIV, v1,  v2))) 
											else   INC(DIVI, (BINARY(DIV, v1,  v2))) 
								end
								else  NODEFINC
							| NOINC -> inc1
							|_->NODEFINC)
	| INC(DIVI,v1)->
   			(match inc2 with INC(DIVI,v2) -> INC(DIVI,(BINARY(MUL,v1,v2)))
							| INC(MULTI,v2) -> 
								let v1Divv2 = calculer  (EXP(BINARY(DIV, v2,  v1))) !infoaffichNull [] 1 in
								let varMoinsUn = (evalexpression (Diff( v1Divv2,  ConstInt("1")))) in
								if estStricPositif v1Divv2 then
								begin
									if estNul varMoinsUn then  NOINC 
									else   if estStricPositif varMoinsUn then   INC(MULTI, (BINARY(DIV, v2,  v1))) 
											else   INC(DIVI, (BINARY(DIV, v2,  v1))) 
								end
								else  NODEFINC
							| NOINC -> inc1
							|_->NODEFINC)
	|_->NODEFINC


and sameType inc1 inc2 =
match inc1 with 
	INC(POSITIV,_)->
   			(match inc2 with INC(POSITIV,_) | NOINC | NODEFINC-> true
							|_->false)
	| INC(NEGATIV,_) ->
		 (	match inc2 with INC(NEGATIV,_) | NOINC | NODEFINC-> true
							|_->false)
	
	| INC(MULTI,v1)->
   			 (	match inc2 with INC(MULTI,_) | NOINC | NODEFINC-> true
							|_->false)
	| INC(DIVI,v1)->
   			 (	match inc2 with INC(DIVI,_) | NOINC | NODEFINC-> true
							|_->false)
	| _ -> true


and joinAlternate  x inc1 inc2 =
match inc1 with 
	INC(POSITIV,v1)->
   			(match inc2 with INC(POSITIV,v2) -> INC(POSITIV,CALL (VARIABLE("MINIMUM") , (List.append [v1] [v2] )))
							|_->NODEFINC)
	| INC(NEGATIV,v1) ->
		 	(match inc2 with INC(NEGATIV,v2) -> INC(NEGATIV,CALL (VARIABLE("MINIMUM") , (List.append [v1] [v2] )))
							|_->NODEFINC)
	| NOINC ->(*Printf.printf "joinAlternate for %s\n"x;*) ( match inc2 with NOINC -> NOINC |_->NODEFINC)
	| NODEFINC -> NODEFINC
	| INC(MULTI,v1)->
   			(match inc2 with INC(MULTI,v2) -> INC(MULTI,CALL (VARIABLE("MINIMUM") , (List.append [v1] [v2] )))	
							|_->NODEFINC)
	| INC(DIVI,v1)->
   			(match inc2 with INC(DIVI,v2) -> INC(DIVI,CALL (VARIABLE("MINIMUM") , (List.append [v1] [v2] )))	
							|_->NODEFINC)
	|_->NODEFINC



and getIncOfInstList x iList completList =
(*Printf.printf "getIncOfInstList variable %s\n" x;
afficherLesAffectations iList;*)
	if iList = [] then (false,NOINC,x,false)
	else
	begin 
		let (firstInst, nextInst) =  (List.hd iList, List.tl iList) in
		match firstInst with
			VAR (id, exp) ->
				 let (isindirect,inc1,v, before) = 
					 if id = x then
						 getInc x (expVaToExp exp) 	
								iList 
								[] 
								false 
								completList
					else (false,NOINC,x, false)  in
				if inc1 = NODEFINC then (false,inc1, x, before)
				else
					if isindirect = false then
					begin
						let (indirect2, inc, var, before2) = getIncOfInstList x nextInst completList  in
						if indirect2 = false then (false, joinSequence x inc1  inc, x, false) else (true, inc, var, before2) 
					end
					else (true, inc1, v, before)

			| TAB (id, _, _) -> 
				if id = x then (false,NODEFINC,x,false) 
				else  (*NOINC *)getIncOfInstList x nextInst completList   
			| MEMASSIGN (id, _, _) -> 
				if id = x then (false,NODEFINC,x,false) 
				else  (*NOINC *)getIncOfInstList x nextInst completList  

			| BEGIN liste ->
				let (indirect1, inc1, var1, before1) = (getIncOfInstList x  liste completList ) in
				if inc1 = NODEFINC then (indirect1,inc1, var1, before1)
				else
					if indirect1 = false then 
					begin 
						let (indirect2, inc2, var2, before2) = (getIncOfInstList x nextInst completList ) in
						if indirect2 = false then (false,joinSequence x inc1 inc2,x, false) else (true, inc2, var2, before2) 
					end
					else (true, inc1, var1,before1) 

			| IFVF (_, i1, i2) ->
				let (indirect1, inc1, var1, before1) = (getIncOfInstList x   [i1] completList ) in
				if inc1 = NODEFINC then (indirect1,inc1, var1, before1)
				else
					if indirect1 = false then 
					begin 
						let (indirect2, inc2, var2, before2) = (getIncOfInstList x [i2] completList ) in
						if inc2 = NODEFINC then (indirect2, inc2, var2, before2) 
						else
							if indirect2 = false then 
							begin
								let (indirect3, inc3, var3, before3) = (getIncOfInstList x  nextInst completList ) in

(*Printf.printf"joinSequence %s\n"x;*)
								if indirect3 = false then  (false,joinSequence x ( joinAlternate x inc1 inc2)  inc3,x, false) 
								else (true, inc3, var3, before3) 
							end
							else (true, inc2, var2, before2) 
						end
						else (true, inc1, var1, before1) 
				

			| IFV ( _, i1) ->
				let (indirect1, inc1, var1, before1) = (getIncOfInstList x   [i1] completList ) in
				if inc1 = NODEFINC then (indirect1,inc1, var1, before1)
				else
					if indirect1 = false then 
					begin 
						let (indirect2, inc2, var2, before2) = (getIncOfInstList x nextInst completList )  in
						if indirect2 = false then   (false,joinSequence x ( joinAlternate x inc1 NOINC)  inc2,x, false)  else (true, inc2, var2, before2) 
					end
					else (true, inc1, var1, before1) 

				

			| FORV (num,id, _, _, _, _, body)->
				let nbItMin = if  existAssosExactLoopInit  num then getAssosExactLoopInit num  else 0 in
				let (indirect1, inc1, var1, before1,incifexe) = (extractIncOfLoop x [body] id nbItMin (*nbItMin_{numLoop}*)completList) in
				(*if nbItMin_{numLoop}=nbItMax_{numLoop} then joinSequence x (extractIncOfLoop x [body] id nbItMin_{numLoop} )(getIncOfInstList x [nextInst])
				else*)
				if inc1 = NODEFINC then (indirect1,inc1, var1, before1)
				else
					if indirect1 = false then 
					begin 
						let (indirect2, inc2, var2, before2) = (getIncOfInstList x nextInst completList )  in
						if indirect2 = false then 
						begin  
							if incifexe = inc1 ||sameType incifexe inc2 then
								(false,(*joinAlternate*) joinSequence x inc1 inc2,x, false)  
							else  (indirect1,NODEFINC, var1, before1)							
						end
						else (true, inc2, var2, before2) 
					end
					else (true, inc1, var1, before1) 


			| APPEL (_,_,_,s,_,_,_)->
				let (indirect1, inc1, var1, before1) = (getIncOfCall x firstInst completList s) in
				if inc1 = NODEFINC then (indirect1,inc1, var1, before1)
				else
					if indirect1 = false then 
					begin 
						let (indirect2, inc2, var2, before2) = (getIncOfInstList x nextInst completList )  in
						if indirect2 = false then   (false,joinSequence x inc1 inc2,x, false)  else (true, inc2, var2, before2) 
					end
					else (true, inc1, var1, before1) 
	end


and extractIncOfLoop x inst varL nbItL completList=
	if nbItL = 0 then
	begin
		
		let las = evalStore (new_instBEGIN(inst)) [] [] in
		let (isindirect,inc1,v, before) = 
			if existAffectVDsListeAS x las then
			begin
				let varBPUN = BINARY(SUB, VARIABLE varL, CONSTANT(CONST_INT("1"))) in
			    isMultiInc := true;
				let extinc = expVaToExp(applyStoreVA (rechercheAffectVDsListeAS x las)  	[ASSIGN_SIMPLE (varL, EXP(varBPUN))] )   in
				getInc x extinc inst !listeASCourant true completList
			end
			else (false,NOINC,x, false) in
		
		 (false,NOINC,x, false, inc1)
	end
	else 
	begin
		listeASCourant := [];
		let las =evalStore (new_instBEGIN(inst)) [] [] in
		let (isindirect,inc1,v, before) = 
			if existAffectVDsListeAS x las then
			begin
				let varBPUN = BINARY(SUB, VARIABLE varL, CONSTANT(CONST_INT("1"))) in
				isMultiInc := true;
				let extinc = expVaToExp(applyStoreVA (rechercheAffectVDsListeAS x las)  	[ASSIGN_SIMPLE (varL, EXP(varBPUN))] )   in
				getInc x extinc inst !listeASCourant true completList
			end
			else (false,NOINC,x, false) in
		 (isindirect,inc1,v, before, inc1) 
	end


and getIncOfCall x call completList s=
if List.mem x !alreadyAffectedGlobales then withoutTakingCallIntoAccount:= false;
let affectSortie = evalStore s [] [] in	

let las = evalStore call [] [] in
if existAffectVDsListeAS x affectSortie then withoutTakingCallIntoAccount:= false;
let inc = 
if existAffectVDsListeAS x las then
begin
			let extinc = expVaToExp(rechercheAffectVDsListeAS x las)   in
			getInc x extinc [call] !listeASCourant true completList
end
else (false,NOINC,x, false) in
withoutTakingCallIntoAccount := true;
inc







and getLoopVarInc v inst =
		isMultiInc := false;(*Printf.printf "getincrement %s \n "v;*)
		let (isindirect,inc,var, before) = getIncOfInstList v inst inst  in

		(* IDEM match  inc  with 
				NODEFINC -> (* pas trouvé d'increment peut être condition = var booleenne *)
						let (isAssignedOK, assign, isConditionnal, ltrue, lfalse) = containBoolxAssignementBody x  inst inst in
						if isAssignedOK then 
								getBooleanAssignementInc  assign isConditionnal ltrue lfalse x
						else 
						begin
							opEstPlus := getIsAddInc inc;
							expressionIncFor :=  getIncValue inc ;
							(isindirect,inc,var, before, !isMultiInc)
						end
				
		|_->*)
			opEstPlus := getIsAddInc inc;
			expressionIncFor :=  getIncValue inc ;
(*
Printf.printf "getincrement %s FIN\n "v;print_intType (getIncType inc);
print_expression !expressionIncFor 0; flush();new_line();flush();flush();new_line();flush();flush();new_line();flush();
Printf.printf "getincrement %s FIN res\n "v;*)


		(isindirect,inc,var, before, !isMultiInc)



