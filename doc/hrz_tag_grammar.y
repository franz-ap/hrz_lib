
// Grammar for tag_string_helper.rb:

%token TAG_START      "<HRZ"
%token TAG_START_CL   "</HRZ"
%token TAG_END_MORE   "+>"
%token TAG_END_CLOSED ">"
%token FUNC_GET_PARAM "get_param"
%token FUNC_SET_PARAM "set_param"
%token FUNC_IF        "if"
%token FUNC_THEN      "then"
%token FUNC_ELSE      "else"
%token FUNC_END_IF    "end_if"
%token OTHER_TEXT     A "word": any text without TAG_* inside and without whitespace, at least one character long.
%token OPERAT_AND     "AND", "&&"
%token OPERAT_OR      "OR",  "||"
%token OPERAT_AND     "NOT", "!"
%token OPERAT_EQUAL   "=="
%token OPERAT_LT      "<"
%token OPERAT_LE      "<="
%token OPERAT_GT      ">"
%token OPERAT_GE      ">="




%start HrzTagText


HrzTagText  : HrzTagText1
            | HrzTagText HrzTagText1
            ;

HrzTagText1 : SingleHrzTag
            | OTextList
            ;

SingleHrzTag: TAG_START HrzFunction HrzParams TAG_END_CLOSED
            | TAG_START HrzFunction HrzParams TAG_END_MORE HrzParams TAG_START_CL HrzFunction TAG_END_CLOSED   // Both HrzFunction must be equal. Both HrzParams go to the same array.
            | TAG_START FUNC_IF TAG_END_CLOSED HrzExprBool TAG_START FUNC_THEN TAG_END_CLOSED HrzTagText                                                   TAG_START FUNC_END_IF TAG_END_CLOSED
            | TAG_START FUNC_IF TAG_END_CLOSED HrzExprBool TAG_START FUNC_THEN TAG_END_CLOSED HrzTagText TAG TAG_START FUNC_ELSE TAG_END_CLOSED HrzTagText TAG_START FUNC_END_IF TAG_END_CLOSED
            ;

HrzParamsArr: '[' HrzParamList ']'  // Result: a (possibly empty) array of strings
            |     HrzParamList
            |
            ;

HrzParamList: HrzParam1
            | HrzParamList ',' HrzParam1
            ;

HrzParam1   : '"' OTextList '"'
            | OTHER_TEXT
            | SingleHrzTag
            ;

OTextList   : OTHER_TEXT                      // A non-empty string without TAG_* inside. Returns that string, WITH the blanks between the words, verbatim from input.
            | OTextList OTHER_TEXT
            ;

HrzFunction : FUNC_GET_PARAM
            | FUNC_SET_PARAM
            ;

HrzExprBool : // The usual boolean expressions plus the constants 'true' and 'false'. Plus numeric comparison of constants and numeric expressions, with * and / precedence, ( and ). The Result is either true or false.

---
Example input strings:
1: abc<HRZ get_param price />def
2: abc<HRZ get_param price, 0.0 />def
3: abc<HRZ get_param>price</HRZ get_param>def

For each of those input strings, a method will be called, that is associated with FUNC_GET_PARAM, e.g. "hrz_strfunc_get_param" with an array of strings:
Case 1 and 3: ["price"]
Case 2:       ["price", "0.0"]

The return value of this method, e.g. "1234" will replace the tag. So, the final output string in case 1, 2 and 3 will be "abc1234def".

One important fact is not descibed by the above grammar yet:
Outside of <HRZ...> tags, any blanks and other whitspace will remain untouched and will be copied to the output string verbatim.
Inside <HRZ...> tags, whitespace is only a "token deliimiter" without meaning any further meaning. In this case it does not matter, if there are multiple occurences of whitepsace in a row or just a single whitespace.
