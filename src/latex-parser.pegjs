{
    var Vector = require('./types').Vector;
    var g = options.generator;
    g.setErrorFn(error);
    g.location = location;
}


// main rule, entry into the parser
// parses a full LaTeX document, or just the contents of the document environment; returns the generator
// 解析器主入口
// 解析整个latex文档,或者文档环境中的内容,并返回html生成器
latex =
    &with_preamble
    (skip_all_space escape (&is_hvmode / &is_preamble) macro)*
    skip_all_space
    (begin_doc / &{ error("expected \\begin{document}") })
        document
    (end_doc / &{ error("\\end{document} missing") })
    .*
    EOF
    { return g; }
    /
    !with_preamble
    // if no preamble was given, start default documentclass
    // 如果没有文档类型说明,开始默认的文档类型
    &{ g.macro("documentclass", [null, g.documentClass, null]); return true; }
    document
    EOF
    { return g; }


// preamble starts with P macro, then only HV and P macros in preamble
// 前导码以P宏开头，前导码中只有HV和P宏
with_preamble =
    skip_all_space escape &is_preamble

begin_doc =
    escape begin _ begin_group "document" end_group

end_doc =
    escape end _ begin_group "document" end_group


// parses everything between \begin{document} and \end{document}; returns the generator
// 解析 \begin {document}和 \end {document}之间的所有内容; 返回html生成器
document =
    & { g.startBalanced(); g.enterGroup(); return true; }
    skip_all_space            // drop spaces at the beginning of the document 删除文档开头的空格
    pars:paragraph*
    skip_all_space            // drop spaces at the end of the document 删除文档末尾的空格
    {
        g.exitGroup();
        g.isBalanced() || error("groups need to be balanced!");
        var l = g.endBalanced();
        // this error should be impossible, it's just to be safe
        // 这个错误应该是不可能的，只是为了安全
        l == 1 && g.isBalanced() || error("grammar error: " + l + " levels of balancing are remaining, or the last level is unbalanced!");

        g.createDocument(pars);
        g.logUndefinedRefs();
        return g;
    }



paragraph =
    vmode_macro
    /
    bb:((escape noindent)? break)*
    _ n:(escape noindent)? txt:text+
    be:break?
    {
        bb.length > 0 && g.break();
        var p = g.create(g.par, txt, n ? "noindent" : "");
        be && g.break();
        return p;
    }



// here, an empty line or \par is just a linebreak - needed in some macro arguments
// 这里，空行或\par只是一个换行符 - 在某些宏参数中需要
paragraph_with_linebreak =
    text
    / vmode_macro
    / break                                     { return g.create(g.linebreak); }


// a line in restricted horizontal mode
// 严格水平模式下的一条线
line =
    linebreak                                   { return undefined; }
    / break                                     { return g.createText(g.sp); }
    / text


text "text" =
    p:(
        ligature
      / primitive
      / !break comment                          { return undefined; }
      // !break, because comment eats a nl and we don't remember that afterwards - space rule also eats a nl
    )+                                          { return g.createText(p.join("")); }

    / linebreak
    / (&unskip_macro _)? m:hmode_macro          { return m; }
    / math

    // groups
    / begin_group                             & { g.enterGroup(true); return true; } // copy attributes 复制属性
      s:space?                                  { return g.createText(s); }
    / end_group                               & { if (!g.isBalanced()) { g.exitGroup(); return true; } } // end group only in unbalanced state 仅在非平衡状态下结束组
      s:space?                                  { return g.createText(s); }


// this rule must always return a string
// 此规则必须始终返回一个字符串
primitive "primitive" =
      char
    / space !unskip_macro                       { return g.sp; }
    / hyphen
    / digit
    / punctuation
    / quotes
    / left_br
                                              // a right bracket is only allowed if we are in an open (unbalanced) group
                                              //只有当我们处于开放（非平衡）组时，才允许使用右括号
    / b:right_br                              & { return !g.isBalanced() } { return b; }
    / nbsp
    / ctrl_space
    / diacritic
    / ctrl_sym
    / symbol
    / charsym
    / utf8_char



/**********/
/* macros 宏*/
/**********/


// macros that work in horizontal and vertical mode (those that basically don't produce text)
// 在水平和垂直模式下工作的宏（那些宏基本上不产生文本）
hv_macro =
    escape
    (
      &is_hvmode macro
      / logging
    )
    { return undefined; }


// macros that only work in horizontal mode (include \leavevmode)
// 仅在水平模式下工作的宏（包括\leavevmode）
hmode_macro =
    hv_macro
  /
    escape
    m:(
      &is_hmode     m:macro         { return m; }
    / &is_hmode_env e:h_environment { return e; }

    / noindent

    / smbskip_hmode / vspace_hmode
    / the

    / verb

    / &is_preamble only_preamble            // preamble macros are not allowed 不允许使用前导码宏
    / !begin !end !is_vmode unknown_macro   // now we have checked hv-macros and h-macros - if it's not a v-macro it is undefined 
                                            //现在我们检查了hv-macros和h-macros  - 如果它不是v-macro它是未定义的
    )
    { return m; }


// macros that only work in vertical mode (include \par or check for \ifvmode)
// 仅在垂直模式下工作的宏（包括\par或检查\ifvmode）
vmode_macro =
    skip_all_space
    hv_macro
    { return undefined; }
  /
    skip_all_space
    escape
    m:(
        &is_vmode     m:macro       { g.break(); return m; }
      / &is_vmode_env e:environment { return e; }
      / vspace_vmode
      / smbskip_vmode
    )
    { return m; }



is_preamble =
    id:identifier &{ return g.isPreamble(id); }

is_vmode =
    id:identifier &{ return g.isVmode(id); }

is_hmode =
    id:identifier &{ return g.isHmode(id); }

is_hvmode =
    id:identifier &{ return g.isHVmode(id); }


is_vmode_env =
    (begin/end) begin_group id:identifier   &{ return g.isVmode(id); }

is_hmode_env =
    begin begin_group id:identifier         &{ return g.isHmode(id) || g.isHVmode(id); }



macro =
    name:identifier _ &{ if (g.hasMacro(name)) { g.beginArgs(name); return true; } }
    macro_args
    {
        var args = g.parsedArgs();
        g.endArgs();
        return g.createFragment(g.macro(name, args));
    }



only_preamble =
    m:identifier
    { error("macro only allowed in preamble: " + m); }

unknown_macro =
    m:identifier
    { error("unknown macro: \\" + m); }



/************************/
/* macro argument rules 宏参数规则*/
/************************/


identifier "identifier" =
    $char+

// key can contain pretty much anything but = and ,
// key 除了 = 和 , 之外几乎可以包含任何东西
key =
    $(char / digit / sp / [-$&_/@] / ![=,] utf8_char)+

key_val "key=value" =
    k:key v:(_ '=' _ v:(key / &{ error("value expected") }) { return v.trim(); })?
    { return { [k.trim()]: v == null ? true : v }; }


macro_args =
    (
        &{ return g.nextArg("X") }                                                                              { g.preExecMacro(); }
      / &{ return g.nextArg("s") }  _ s:"*"?                                                                    { g.addParsedArg(!!s); }

      / &{ return g.nextArg("g") }    a:(arg_group      / &{ g.argError("group argument expected") })           { g.addParsedArg(a); }
      / &{ return g.nextArg("hg") }   a:(arg_hgroup     / &{ g.argError("group argument expected") })           { g.addParsedArg(a); }
      / &{ return g.nextArg("h") }    h:(horizontal     / &{ g.argError("horizontal material expected") })      { g.addParsedArg(h); }
      / &{ return g.nextArg("o?") }   o: opt_group?                                                             { g.addParsedArg(o); }

      / &{ return g.nextArg("i") }    i:(id_group       / &{ g.argError("id group argument expected") })        { g.addParsedArg(i); }
      / &{ return g.nextArg("i?") }   i: id_optgroup?                                                           { g.addParsedArg(i); }
      / &{ return g.nextArg("k") }    k:(key_group      / &{ g.argError("key group argument expected") })       { g.addParsedArg(k); }
      / &{ return g.nextArg("k?") }   k: key_optgroup?                                                          { g.addParsedArg(k); }
      / &{ return g.nextArg("kv?") }  k: keyval_optgroup?                                                       { g.addParsedArg(k); }
      / &{ return g.nextArg("csv") }  v:(csv_group      / &{ g.argError("comma-sep. values group expected") })  { g.addParsedArg(v); }

      / &{ return g.nextArg("n") }    n:(expr_group     / &{ g.argError("num group argument expected") })       { g.addParsedArg(n); }
      / &{ return g.nextArg("n?") }   n: expr_optgroup?                                                         { g.addParsedArg(n); }
      / &{ return g.nextArg("l") }    l:(length_group   / &{ g.argError("length group argument expected") })    { g.addParsedArg(l); }
      / &{ return g.nextArg("lg?") }  l: length_group?                                                          { g.addParsedArg(l); }
      / &{ return g.nextArg("l?") }   l: length_optgroup?                                                       { g.addParsedArg(l); }
      / &{ return g.nextArg("m") }    m:(macro_group    / &{ g.argError("macro group argument expected") })     { g.addParsedArg(m); }
      / &{ return g.nextArg("u") }    u:(url_group      / &{ g.argError("url group argument expected") })       { g.addParsedArg(u); }
      / &{ return g.nextArg("c") }    c:(color_group    / &{ g.argError("color group expected") })              { g.addParsedArg(c); }
      / &{ return g.nextArg("cl") }   c:(coord_group    / &{ g.argError("coordinate/length group expected") })  { g.addParsedArg(c); }
      / &{ return g.nextArg("cl?") }  c: coord_optgroup?                                                        { g.addParsedArg(c); }
      / &{ return g.nextArg("v") }    v:(vector         / &{ g.argError("coordinate pair expected") })          { g.addParsedArg(v); }
      / &{ return g.nextArg("v?") }   v: vector?                                                                { g.addParsedArg(v); }
      / &{ return g.nextArg("cols") } c:(columns        / &{ g.argError("column specification missing") })      { g.addParsedArg(c); }

      / &{ return g.nextArg("is") }   skip_space

      / &{ return g.nextArg("items") }      i:items                                                             { g.addParsedArg(i); }
      / &{ return g.nextArg("enumitems") }  i:enumitems                                                         { g.addParsedArg(i); }
    )*


// {identifier}
id_group        =   _ begin_group _
                        id:identifier
                    _ end_group
                    { return id; }

// {\identifier}
macro_group     =   _ begin_group _
                        escape id:identifier
                    _ end_group
                    { return id; }

// [identifier]
id_optgroup     =   _ begin_optgroup _
                        id:identifier
                    _ end_optgroup
                    { return id; }

// {key}
key_group       =   _ begin_group _
                        k:key
                    _ end_group
                    { return k; }

// [key]
key_optgroup    =   _ begin_optgroup _
                        k:key
                    _ end_optgroup
                    { return k; }


// [key-val list]  (key1=val1,key2=val2)
keyval_optgroup =   _ begin_optgroup
                        kv_list:(_ ',' {return null;} / _ kv:key_val {return kv;})*
                    _ end_optgroup
                    {
                        return kv_list.filter(kv => kv != null);
                    }

// {val1,val2,val3}
csv_group       =   _ begin_group _
                        v_list:(_ ',' {return null;} / _ v:key {return v.trim();})*
                    _ end_group
                    {
                        return v_list.filter(v => v != null);
                    }

// lengths
length_unit     =   _ u:("sp" / "pt" / "px" / "dd" / "mm" / "pc" / "cc" / "cm" / "in" / "ex" / "em") !char _
                    { return u; }

  // TODO: should be able to use variables and maths: 2\parskip etc.
  // TODO：应该能够使用变量和数学：2 \parskip等。
length          =   l:float u:length_unit (plus float length_unit)? (minus float length_unit)?
                    { return new g.Length(l, u); }

// {length}
length_group    =   _ begin_group _
                        l:length
                    end_group
                    { return l; }

// [length]
length_optgroup =   _ begin_optgroup _
                        l:length
                    end_optgroup
                    { return l; }


// {num expression}
expr_group      =   _ begin_group
                        n:num_expr
                    end_group
                    { return n; }

// [num expression]
expr_optgroup  =   _ begin_optgroup
                        n:num_expr
                    end_optgroup
                    { return n; }

// {float expression}
float_group     =   _ begin_group
                        // TODO
                    end_group
                    { return f; }


// {color}
color_group     =   _ begin_group
                        c:color
                    end_group
                    { return c; }


// picture coordinates and vectors
// 图片坐标和向量

// float or length
coordinate      =   _ c:(length / f:float { return g.length("unitlength").mul(f) }) _
                    { return c; }

// (coord, coord)
vector          =   _ "(" x:coordinate "," y:coordinate ")" _
                    { return new Vector(x, y); }


// {coord}
coord_group     =   _ begin_group
                        c:coordinate
                    end_group
                    { return c; }

// [coord]
coord_optgroup  =   _ begin_optgroup
                        c:coordinate
                    end_optgroup
                    { return c; }



url_pct_encoded =   escape? p:$("%" hex hex) { return p; }

url_char        =   char / digit / [-._~:/?#[\]@!$&()*+,;=] / "'" / url_pct_encoded
                    / &{ error("illegal char in url given"); }

// {url}
url_group       =   _ begin_group _
                        url:(!(_ end_group) c:url_char {return c;})+
                    _ end_group
                    { return url.join(""); }



// {<LaTeX code/text>}
//
// group balancing: groups have to be balanced inside arguments, inside environments, and inside a document.
// 组平衡：组必须在参数，内部环境和文档内部进行平衡
// startBalanced() is used to start a new level inside of which groups have to be balanced.
// startBalanced（）用于启动必须平衡组的新级别。
//
// In the document and in environments, the default state is unbalanced until end of document or environment.
// 在文档和环境中，默认状态是不平衡的，直到文档或环境结束。
// In an argument, the default state is balanced (so that we know when to take } as end of argument),
// 在一个参数中，默认状态是平衡的（因此我们知道何时采用}作为参数的结尾），
// so first enter the group, then start a new level of balancing.
// 所以首先进入组，然后开始一个新的平衡水平。
arg_group       =   _ begin_group      & { g.enterGroup(); g.startBalanced(); return true; }
                        s:space?
                        p:paragraph_with_linebreak*
                    end_group
                    {
                        g.isBalanced() || error("groups inside an argument need to be balanced!");
                        g.endBalanced();
                        g.exitGroup();

                        s != undefined && p.unshift(g.createText(s));
                        return g.createFragment(p);
                    }


// restricted horizontal material
// 限制水平材料
horizontal      =   l:line*
                    { return g.createFragment(l); }

// restricted horizontal mode group
// 受限水平模式组
arg_hgroup      =   _ begin_group      & { g.enterGroup(); g.startBalanced(); return true; }
                        s:space?
                        h:horizontal
                    end_group
                    {
                        g.isBalanced() || error("groups inside an argument need to be balanced!");
                        g.endBalanced();
                        g.exitGroup();
                        return g.createFragment(g.createText(s), h);
                    }


// [<LaTeX code/text>]
opt_group       =   _ begin_optgroup   & { g.enterGroup(); g.startBalanced(); return true; }
                        p:paragraph_with_linebreak*
                    end_optgroup                & { return g.isBalanced(); }
                    {
                        g.isBalanced() || error("groups inside an optional argument need to be balanced!");
                        g.endBalanced();
                        g.exitGroup();
                        return g.createFragment(p);
                    }



// calc expressions 计算表达式//


// \value{counter}
value           =   escape "value" c:id_group               { return c; }

// \real{<float>}
real            =   escape "real" _
                    begin_group _ f:float _ end_group       { return f; }



num_value       =   "(" expr:num_expr ")"                   { return expr; }
                  / integer
                  / real
                  / c:value                                 { return g.counter(c); }

num_factor      =   s:("+"/"-") _ n:num_factor     { return s == "-" ? -n : n; }
                  / num_value

num_term        =   head:num_factor tail:(_ ("*" / "/") _ num_factor)*
                {
                    var result = head, i;

                    for (i = 0; i < tail.length; i++) {
                        if (tail[i][1] === "*") { result = Math.trunc(result * tail[i][3]); }
                        if (tail[i][1] === "/") { result = Math.trunc(result / tail[i][3]); }
                    }

                    return Math.trunc(result);
                }

num_expr        =   _ head:num_term tail:(_ ("+" / "-") _ num_term)* _
                {
                    var result = head, i;

                    for (i = 0; i < tail.length; i++) {
                        if (tail[i][1] === "+") { result += tail[i][3]; }
                        if (tail[i][1] === "-") { result -= tail[i][3]; }
                    }

                    return result;
                }



// xcolor expressions xcolor表达式//

color           = (c_name / c_ext_expr / c_expr) func_expr*

c_ext_expr      = core_model "," d:int ":" (c_expr "," float)+

c_expr          = c_prefix? c_name c_mix_expr c_postfix?

c_mix_expr      = ("!" c_pct "!" c_name)* "!" c_pct ("!" c_name)?

// c_mix_expr      = ("!" c_pct "!" c_name)+
//                 / ("!" c_pct "!" c_name)* "!" c_pct ("!" c_name)?

func_expr       = fn ("," fn_arg)*

fn              = ">" ("wheel" / "twheel")

fn_arg          = float     // TODO...


c_prefix        = m:"-"* { return m.length % 2 == 0; }

c_name          = $(char / digit / ".")+

c_pct           = float

c_postfix       = "!!" (m:"+"+ / "[" int "]")


color_model     = core_model / int_model / dec_model / pseudo_model

core_model      = "rgb" / "cmy" / "cmyk" / "hsb" / "gray"

int_model       = "RBG" / "HTML" / "HSB" / "Gray"

dec_model       = "Hsb" / "tHsb" / "wave"

pseudo_model    = "named"

c_type          = "named" / "ps"


color_spec      = float ((sp / ",") float)*
                / c_name

color_spec_list = color_spec ("/" color_spec)*


model_list      = (core_model ":")? color_model ("/" color_model)*


// column spec for tables like tabular
// 表格的列规范，如tabular
columns =
    begin_group
        s:column_separator*
        c:(_c:column _s:column_separator* { return Array.isArray(_c) ? _c.concat(_s) : [_c].concat(_s); })+
    end_group
    {
        return c.reduce(function(a, b) { return a.concat(b); }, s)
    }

column =
    c:("l"/"c"/"r"/"p" l:length_group { return l; })
    {
        return c;
    }
    /
    "*" reps:expr_group c:columns
    {
        var result = []
        for (var i = 0; i < reps; i++) {
            result = result.concat(c.slice())
        }
        return result
    }

column_separator =
    s:("|" / "@" a:arg_group { return a; })
    {
        return {
            type: "separator",
            content: s
        }
    }



// **** macros the parser has to know about due to special parsing that is neccessary **** //
// **** 宏是解析器必须知道的，因为需要进行特殊的解析 ****//


// spacing macros
// 间隔宏

// vertical
// 垂直
vspace_hmode    =   "vspace" "*"?   l:length_group      { return g.createVSpaceInline(l); }
vspace_vmode    =   "vspace" "*"?   l:length_group      { return g.createVSpace(l); }

smbskip_hmode   =   s:$("small"/"med"/"big")"skip" !char _ { return g.createVSpaceSkipInline(s + "skip"); }
smbskip_vmode   =   s:$("small"/"med"/"big")"skip" !char _ { return g.createVSpaceSkip(s + "skip"); }

//  \\[length] is defined in the linebreak rule further down
// \\ [length]在换行符规则中进一步定义



// verb - one-line verbatim text
// verb - 一行逐字文字

// TODO: this should use the current font size!
// TODO：这应该使用当前的字体大小！
verb            =   "verb" s:"*"? _ !char
                    b:.
                        v:$(!nl t:. !{ return b == t; })*
                    e:.
                    {
                        b == e || error("\\verb is missing its end delimiter: " + b);
                        if (s)
                            v = v.replace(/ /g, g.visp);

                        return g.create(g.verb, g.createVerbatim(v, true));
                    }




/****************/
/* environments 环境*/
/****************/

begin_env "\\begin" =
    // escape already eaten by macro rule
    // escape 已经被宏规则吃掉了
    begin
    begin_group id:identifier end_group
    {
        g.begin(id);
        return id;
    }

end_env "\\end" =
    skip_all_space
    escape end
    begin_group id:identifier end_group
    {
        return id;
    }


// trivlists: center, flushleft, flushright, verbatim, tabbing, theorem
// lists: itemize, enumerate, description, verse, quotation, quote, thebibliography
// 列表：逐项列出，枚举，描述，诗歌，引文，引用，参考书目
//
// both, lists and trivlists, add a \par at their beginning and end, but do not indent
// both，lists 和 trivlists，在开头和结尾添加\par，但不要缩进
// if no other \par (or empty line) follows them.
// 如果没有其他\par（或空行）跟随它们。
//
// all other environments are "inline" environments, and those indent
// 所有其他环境都是“内联”环境，那些缩进也是

h_environment =
    id:begin_env
        macro_args                                          // parse macro args (which now become environment args)
                                                            //解析宏args（现在变成环境args）
        node:( &. { return g.macro(id, g.endArgs()); })     // then execute macro with args without consuming input
                                                            //然后用args执行宏而不消耗输入
        sb:(s:space? {return g.createText(s); })
        p:paragraph_with_linebreak*                         // then parse environment contents (if macro left some)
                                                            //然后解析环境内容（如果宏留下一些）
    end_id:end_env se:(s:space? {return g.createText(s); })
    {
        var end = g.end(id, end_id);

        // if nodes are created by macro, add content as children to the last element
        // if node is a text node, just add it
        // potential spaces after \begin and \end have to be added explicitely
        
        // 如果节点是由宏创建的，则将内容作为子节点添加到最后一个元素
        // 如果node是文本节点，只需添加它
        // 必须明确地添加\ begin和\ end之后的潜在空格

        var pf = g.createFragment(p);
        if (pf && node && node.length > 0 && node[node.length - 1].nodeType === 1) {
            node[node.length - 1].appendChild(sb);
            node[node.length - 1].appendChild(pf);
            return g.createFragment(node, end, se);
        }

        return g.createFragment(node, sb, pf, end, se);     // use pf, fragments in p are now empty!! 使用pf，p中的片段现在是空的!!
    }



environment =
    id:begin_env  !{ g.break(); }
        macro_args                                          // parse macro args (which now become environment args)
                                                            // 解析宏args（现在变成环境args）
        node:( &. { return g.macro(id, g.endArgs()); })     // then execute macro with args without consuming input
                                                            //然后用args执行宏而不消耗输入
        p:paragraph*                                        // then parse environment contents (if macro left some)
                                                            //然后解析环境内容（如果宏留下一些）
    end_id:end_env
    {
        var end = g.end(id, end_id);

        // if nodes are created by macro, add content as children to the last element
        // if node is a text node, just add it
        
        //如果节点是由宏创建的，则将内容作为子节点添加到最后一个元素
        //如果node是文本节点，只需添加它

        var pf = g.createFragment(p);
        if (pf && node && node.length > 0 && node[node.length - 1].nodeType === 1) {
            node[node.length - 1].appendChild(pf);
            return g.createFragment(node, end);
        }
        return g.createFragment(node, pf, end);
    }





// lists: items, enumerated items
// 列出：项目，枚举项目


item =
    skip_all_space escape "item" !char !{ g.break(); } og:opt_group? skip_all_space
    { return og; }

// items without a counter
// items 没有计数器
items =
    (
        (skip_all_space hv_macro)*
        label:item
        pars:(!(item/end_env) p:paragraph { return p; })*   // collect paragraphs in pars
        {
            return {
                label: label,
                text: g.createFragment(pars)
            };
        }
    )*

// enumerated items
// 枚举类型
enumitems =
    (
        (skip_all_space hv_macro)*
        label:(label:item {
            // null is no opt_group (\item ...)
            // undefined is an empty one (\item[] ...)
            // null是没有opt_group（\ item ...）
            // undefined是空的（\ item [] ......）
            
            if (label === null) {
                var itemCounter = "enum" + g.roman(g.counter("@enumdepth"));
                var itemId = "item-" + g.nextId();
                g.stepCounter(itemCounter);
                g.refCounter(itemCounter, itemId);
                return {
                    id:   itemId,
                    node: g.macro("label" + itemCounter)
                };
            }
            return {
                id: undefined,
                node: label
            };
        })
        pars:(!(item/end_env) p:paragraph { return p; })*   // collect paragraphs in pars 收集pars中的段落
        {
            return {
                label: label,
                text: g.createFragment(pars)
            };
        }
    )*



// comment
// 注释

comment_env "comment environment" =
    "\\begin" _ "{comment}"
        (!end_comment .)*
    end_comment _
    { g.break(); return undefined; }

end_comment = "\\end" _ "{comment}"




/**********/
/*  math  数学*/
/**********/


math =
    inline_math / display_math

inline_math =
    math_shift            m:$math_primitive+ math_shift            { return g.parseMath(m, false); }
    / escape "("          m:$math_primitive+ escape ")"            { return g.parseMath(m, false); }

display_math =
    math_shift math_shift m:$math_primitive+ math_shift math_shift { return g.parseMath(m, true); }
    / escape left_br      m:$math_primitive+ escape right_br       { return g.parseMath(m, true); }


math_primitive =
    primitive
    / alignment_tab
    / superscript
    / subscript
    / escape identifier
    / begin_group _ end_group
    / begin_group math_primitive+ end_group
    / sp / nl / linebreak / comment


// shortcut 快捷方式
_                           = skip_space

/* kind of keywords 关键词 */

begin                       = "begin"    !char _   {}
end                         = "end"      !char _   {}

par                         = "par"      !char     {}
noindent                    = "noindent" !char _   {}

plus                        = "plus"     !char _   {}
minus                       = "minus"    !char _   {}

endinput                    = "endinput" !char _   .*


/* syntax tokens - TeX's first catcodes that generate no output */
// 语法标记 -  TeX的第一个不生成输出的catcodes

escape                      = "\\"                              { return undefined; }       // catcode 0
begin_group                 = "{"                               { return undefined; }       // catcode 1
end_group                   = "}"                               { return undefined; }       // catcode 2
math_shift      "math"      = "$"                               { return undefined; }       // catcode 3
alignment_tab               = "&"                               { return undefined; }       // catcode 4

macro_parameter "parameter" = "#"                               { return undefined; }       // catcode 6
superscript                 = "^"                               { return undefined; }       // catcode 7
subscript                   = "_"                               { return undefined; }       // catcode 8
ignore                      = "\0"                              { return undefined; }       // catcode 9

EOF             "EOF"       = !. / escape endinput




/* space handling 空间处理 */

nl              "newline"   = "\n" / "\r\n" / "\r"
                            / "\u2028" / "\u2029"               { return undefined; }       // catcode 5 (linux, os x, windows, unicode)
sp              "whitespace"= [ \t]                             { return undefined; }       // catcode 10

comment         "comment"   = "%"  (!nl .)* (nl sp* / EOF)                                  // catcode 14, including the newline
                            / comment_env                       { return undefined; }       //             and the comment environment

skip_space      "spaces"    = (!break (nl / sp / comment))*     { return undefined; }
skip_all_space  "spaces"    = (nl / sp / comment)*              { return undefined; }

space           "spaces"    = !break
                              !linebreak
                              !(skip_all_space escape (is_vmode/is_vmode_env))
                              (sp / nl)+                        { return g.brsp; }

ctrl_space  "control space" = escape (&nl &break / nl / sp)     { return g.brsp; }          // latex.ltx, line 540

nbsp        "non-brk space" = "~"                               { return g.nbsp; }          // catcode 13 (active)

break     "paragraph break" = ((skip_all_space escape par skip_all_space)+                  // a paragraph break is either \par embedded in spaces,
                                                                                            // 段落是嵌入空格的\ par，
                               /                                                            // or
                               sp*
                               (nl comment* / comment+)                                     // a paragraph break is a newline...
                                                                                            // 分节符是换行符...
                               ((sp* nl)+ / &end_doc / EOF)                                 // ...followed by one or more newlines, mixed with spaces,...
                                                                                            // ...后跟一个或多个换行符，与空格混合，......
                               (sp / nl / comment)*                                         // ...and optionally followed by any whitespace and/or comment
                                                                                            // ...并且可选地后跟任何空格和/或注释
                              )                                 { return true; }

linebreak       "linebreak" = _ escape "\\" _ '*'? _
                              l:(begin_optgroup _
                                    l:length
                                end_optgroup _ {return l;})?
                              {
                                  if (l) return g.createBreakSpace(l);
                                  else   return g.create(g.linebreak);
                              }

// this should hold all macros that unskip (\\ is already in linebreak) [or add a new macro type?]
// 这应该包含所有解压缩的宏（\\已经在换行符中）[或者添加一个新的宏类型？]
unskip_macro                = _ escape ("put"/"newline") !char


/* syntax tokens 语法标记 - LaTeX */

// Note that these are in reality also just text! I'm just using a separate rule to make it look like syntax, but
// brackets do not need to be balanced.
// 请注意，这些实际上也只是文字！我只是使用一个单独的规则使它看起来像语法，但是
// 括号不需要平衡。

begin_optgroup              = "["                               { return undefined; }
end_optgroup                = "]"                               { return undefined; }


/* text tokens - symbols that generate output 文本标记 - 生成输出的符号 */

char        "letter"        = c:[a-z]i                          { return g.character(c); }  // catcode 11
digit       "digit"         = n:[0-9]                           { return g.character(n); }  // catcode 12 (other)
punctuation "punctuation"   = p:[.,;:\*/()!?=+<>]               { return g.character(p); }  // catcode 12
quotes      "quotes"        = q:[`']                            { return g.textquote(q); }  // catcode 12
left_br     "left bracket"  = b:"["                             { return g.character(b); }  // catcode 12
right_br    "right bracket" = b:"]"                             { return g.character(b); }  // catcode 12

utf8_char   "utf8 char"     = !(sp / nl / escape / begin_group / end_group / math_shift / alignment_tab / macro_parameter /
                                superscript / subscript / ignore / comment / begin_optgroup / end_optgroup /* primitive */)
                               u:.                              { return g.character(u); }  // catcode 12 (other)

hyphen      "hyphen"        = "-"                               { return g.hyphen(); }

ligature    "ligature"      = l:("ffi" / "ffl" / "ff" / "fi" / "fl" / "---" / "--"
                                / "``" / "''" / "!´" / "?´" / "<<" / ">>")
                                                                { return g.ligature(l); }

ctrl_sym    "control symbol"= escape c:[$%#&{}_\-,/@]           { return g.controlSymbol(c); }


// returns a unicode char/string
// 返回一个unicode char / string
symbol      "symbol macro"  = escape name:identifier &{ return g.hasSymbol(name); } _
    {
        return g.symbol(name);
    }


diacritic "diacritic macro" =
    escape
    d:$(char !char / !char .)  &{ return g.hasDiacritic(d); }
    _
    c:(begin_group c:primitive? end_group s:space? { return g.diacritic(d, c) + (s ? s:""); }
      /            c:primitive                     { return g.diacritic(d, c); })
    {
        return c;
    }



/* TeX language 语言*/

// \symbol{}= \char
// \char98  = decimal 98
// \char'77 = octal 77
// \char"FF = hex FF
// ^^FF     = hex FF
// ^^^^FFFF = hex FFFF
// ^^c      = if charcode(c) < 64 then fromCharCode(c+64) else fromCharCode(c-64)
charsym     = escape "symbol"
              begin_group _ i:integer _ end_group               { return String.fromCharCode(i); }
            / escape "char" i:integer                           { return String.fromCharCode(i); }
            / "^^^^" i:hex16                                    { return String.fromCharCode(i); }
            / "^^"   i:hex8                                     { return String.fromCharCode(i); }
            / "^^"   c:.                                        { c = c.charCodeAt(0);
                                                                  return String.fromCharCode(c < 64 ? c + 64 : c - 64); }


integer     =     i:int                                         { return parseInt(i, 10); }
            / "'" o:oct                                         { return parseInt(o, 8); }
            / '"' h:(hex16/hex8)                                { return h; }


hex8  "8bit hex value"  = h:$(hex hex)                          { return parseInt(h, 16); }
hex16 "16bit hex value" = h:$(hex hex hex hex)                  { return parseInt(h, 16); }

int   "integer value"   = $[0-9]+
oct   "octal value"     = $[0-7]+
hex   "hex digit"       = [a-f0-9]i

float "float value"     = f:$(
                            [+\-]? (int ('.' int?)? / '.' int)
                          )                                     { return parseFloat(f); }


// distinguish length/counter: if it's not a counter, it is a length
// 区分长度/计数器：如果它不是计数器，则为长度
the                     = "the" !char _ t:(
                            c:value &{ return g.hasCounter(c);} { return g.createText("" + g.counter(c)); }
                            / escape id:identifier _            { return g.theLength(id); }
                        )                                       { return t; }

// logging
// 记录
logging                 = "showthe" !char _ (
                            c:value &{ return g.hasCounter(c);} { console.log(g.counter(c)); }
                            / escape l:identifier _             { console.log(g.length(l)); }
                        )
                        / "message" m:arg_group                 { console.log(m.textContent); }
