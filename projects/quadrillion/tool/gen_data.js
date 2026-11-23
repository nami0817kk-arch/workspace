// 試作の定数を Dart の data.dart に書き出す
const fs=require('fs'),vm=require('vm');
const html=fs.readFileSync(process.argv[2],'utf8');
const code=html.match(/<script id="logic">([\s\S]*?)<\/script>/)[1];
const ctx={console,Math,JSON,Object,Array,Set,String,Number,isFinite};vm.createContext(ctx);
vm.runInContext(code+';this.D={IND,SYN,BIG,TRAITS,STRAITS,RIVALS,RTYPE,SEI,MEI,CO_A,CO_F,CO_C,CO_SUF,CO_FSUF,NAMEP,NAMEC,CTRY,MODELN,MODELD,MODELS_BY,ENTRYN,DEALN,DEALD,DIRTYN,DIRTYD,CULT,PLACES,NETMSG,ABN,CATN,REGN,CITY}',ctx);
const D=ctx.D;
const s=x=>"'"+String(x).replace(/\\/g,'\\\\').replace(/'/g,"\\'").replace(/\$/g,'\\$')+"'";
const n=x=>{const t=String(x);return /[.e]/.test(t)?t:t+'.0'};
const i=x=>String(x);
const sl=a=>'['+a.map(s).join(', ')+']';
const sm=o=>'{'+Object.entries(o).map(([k,v])=>s(k)+': '+s(v)).join(', ')+'}';
let out=`// 試作（prototype.html）の定数をそのまま写したもの。tool で生成した。手で直すときは試作と食い違わないように。
// ignore_for_file: constant_identifier_names

import 'models_static.dart';

`;
out+='const List<Industry> IND = [\n'+D.IND.map(x=>`  Industry(${s(x.id)}, ${s(x.name)}, ${s(x.cat)}, ${i(x.b)}, ${i(x.p)}, ${i(x.f)}, ${n(x.mg)}, ${n(x.sens)}, ${n(x.capex)}, ${n(x.size)}, ${s(x.key)}),`).join('\n')+'\n];\n\n';
out+='const List<Synergy> SYN = [\n'+D.SYN.map(x=>`  Synergy(${s(x.a)}, ${s(x.b)}, ${s(x.name)}),`).join('\n')+'\n];\n\n';
out+='const List<BigSynergy> BIG = [\n'+D.BIG.map(x=>`  BigSynergy(${s(x.k)}, ${s(x.name)}, ${sl(x.set)}),`).join('\n')+'\n];\n\n';
out+='const List<Trait> TRAITS = [\n'+D.TRAITS.map(x=>`  Trait(${s(x.id)}, ${s(x.n)}, ${s(x.g)}, ${s(x.b)}),`).join('\n')+'\n];\n\n';
out+='const List<Trait> STRAITS = [\n'+D.STRAITS.map(x=>`  Trait(${s(x.id)}, ${s(x.n)}, ${s(x.g)}, ${s(x.b)}),`).join('\n')+'\n];\n\n';
out+='const List<RivalDef> RIVALS = [\n'+D.RIVALS.map(x=>`  RivalDef(${s(x.k)}, ${s(x.pres)}, ${s(x.co)}, ${s(x.type)}, ${x.label?s(x.label):'null'}, ${i(x.tier)}, ${s(x.col)}),`).join('\n')+'\n];\n\n';
out+='const Map<String, String> RTYPE = '+sm(D.RTYPE)+';\n\n';
for(const k of ['SEI','MEI','CO_A','CO_F','CO_C','NETMSG','REGN','CITY'])out+=`const List<String> ${k} = ${sl(D[k])};\n\n`;
for(const k of ['CO_SUF','CO_FSUF','NAMEC','MODELN','MODELD','ENTRYN','DEALN','DEALD','DIRTYN','DIRTYD','ABN','CATN','RTYPE'].filter(k=>k!=='RTYPE'))out+=`const Map<String, String> ${k} = ${sm(D[k])};\n\n`;
out+='const Map<String, List<List<String>>> NAMEP = {\n'+Object.entries(D.NAMEP).map(([k,v])=>`  ${s(k)}: [${sl(v[0])}, ${sl(v[1])}],`).join('\n')+'\n};\n\n';
out+='const List<Country> CTRY = [\n'+D.CTRY.map(x=>`  Country(${s(x.c)}, ${s(x.n)}, ${s(x.city)}, ${n(x.a)}, ${n(x.b)}, ${n(x.m)}, ${n(x.k)}),`).join('\n')+'\n];\n\n';
out+='const Map<String, Set<String>> MODELS_BY = {\n'+Object.entries(D.MODELS_BY).map(([k,v])=>`  ${s(k)}: {${[...v].map(s).join(', ')}},`).join('\n')+'\n};\n\n';
out+='const Map<String, Culture> CULT = {\n'+Object.entries(D.CULT).map(([k,v])=>`  ${s(k)}: Culture(${s(v.n)}, ${s(v.g)}, ${s(v.b)}),`).join('\n')+'\n};\n\n';
out+='const List<Place> PLACES = [\n'+D.PLACES.map(x=>`  Place(${s(x.id)}, ${s(x.n)}, ${s(x.s)}),`).join('\n')+'\n];\n';
fs.writeFileSync(process.argv[3],out);
console.log('ok',D.IND.length,D.SYN.length);
