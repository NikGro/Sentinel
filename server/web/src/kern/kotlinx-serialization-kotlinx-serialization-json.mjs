import {
  EmptySerializersModule991ju6pz9b79 as EmptySerializersModule,
  Decoder23nde051s631g as Decoder,
  CompositeDecoder2tzm7wpwkr0og as CompositeDecoder,
  serializer1x79l67jvwntn as serializer,
  InlinePrimitiveDescriptor3i6ccn1a4fw94 as InlinePrimitiveDescriptor,
  SerializableWithd2dap36updxd as SerializableWith,
  ListSerializer1hxuk9dx5n9du as ListSerializer,
  SerialDescriptor2pelqekb5ic3a as SerialDescriptor,
  KSerializerzf77vz1967fq as KSerializer,
  SEALED_getInstance2pc3convncp73 as SEALED_getInstance,
  buildSerialDescriptor2873qmkp8r2ib as buildSerialDescriptor,
  MapSerializer11kmegt3g5c1g as MapSerializer,
  STRING_getInstance1ov5zayfui8fl as STRING_getInstance,
  ENUM_getInstance1f3d4zr61j5rk as ENUM_getInstance,
  PrimitiveSerialDescriptor3egfp53lutxj2 as PrimitiveSerialDescriptor,
  get_isNullable36pbikm8xb7bz as get_isNullable,
  get_isInline5x26qrhi9qs6 as get_isInline,
  get_annotationshjxdbdcl8kmv as get_annotations,
  SerializationExceptioneqrdve3ts2n9 as SerializationException,
  ElementMarker33ojvsajwmzts as ElementMarker,
  CLASS_getInstance3ax1g1upf6nuo as CLASS_getInstance,
  LIST_getInstance2xmlsct1exo3w as LIST_getInstance,
  CONTEXTUAL_getInstance2bsxm25kydylq as CONTEXTUAL_getInstance,
  PolymorphicKindla9gurooefwb as PolymorphicKind,
  PrimitiveKindndgbuh6is7ze as PrimitiveKind,
  MAP_getInstance173r3f2itu405 as MAP_getInstance,
  ENUMlmq49cvwy4ow as ENUM,
  contextual3hpp1gupsu4al as contextual,
  SerializersModuleCollector3dddz14wd7brg as SerializersModuleCollector,
  AbstractDecoder35guh02ubh2hm as AbstractDecoder,
  AbstractPolymorphicSerializer1ccxwp48nfy58 as AbstractPolymorphicSerializer,
  DeserializationStrategy1z3z5pj9f7zc8 as DeserializationStrategy,
  findPolymorphicSerializer1nm87hvemahcj as findPolymorphicSerializer,
  missingFieldExceptionWithNewMessage2gqddjx5jxge9 as missingFieldExceptionWithNewMessage,
  MissingFieldException24tqif29emcmi as MissingFieldException,
  serializer3ikrxnm8b29d6 as serializer_0,
  serializer2lw83vwvpnyms as serializer_1,
  serializer36584sjyg5661 as serializer_2,
  serializer1q7c5q67ysppr as serializer_3,
  NamedValueDecoderzk26ztf92xbq as NamedValueDecoder,
  jsonCachedSerialNameslxufy2gu43jt as jsonCachedSerialNames,
  getContextualDescriptor2n1gf3b895yb8 as getContextualDescriptor,
} from './kotlinx-serialization-kotlinx-serialization-core.mjs';
import {
  initMetadataForObject1cxne3s9w65el as initMetadataForObject,
  VOID3gxj6tk5isa35 as VOID,
  initMetadataForClassbxx6q50dy2s7 as initMetadataForClass,
  IllegalArgumentException2asla15b5jaob as IllegalArgumentException,
  toString1pkumu07cwy4m as toString,
  Unit_instance3vdlo4e4f5ggx as Unit_instance,
  charSequenceLength3278n89t01tmv as charSequenceLength,
  charSequenceGet1vxk1y5n17t1z as charSequenceGet,
  _Char___init__impl__6a9atx2yltdocdrxs4d as _Char___init__impl__6a9atx,
  equals2au1ep9vhcato as equals,
  toString30pk9tzaqopn as toString_0,
  Enum3alwj03lh1n41 as Enum,
  initMetadataForInterface1egvbzx539z91 as initMetadataForInterface,
  initMetadataForCompanion1wyw17z38v6ac as initMetadataForCompanion,
  hashCodeq5arwsb9dgti as hashCode,
  joinToString1cxrrlmo0chqs as joinToString,
  THROW_CCE2g6jy02ryeudk as THROW_CCE,
  KtList3hktaavzmj137 as KtList,
  StringBuildermazzzhj6kkai as StringBuilder,
  KtMap140uvy3s5zad8 as KtMap,
  toDouble1kn912gjoizjp as toDouble,
  getKClassFromExpression348iqjl4fnx2f as getKClassFromExpression,
  getBooleanHashCode1bbj3u6b3v0a7 as getBooleanHashCode,
  getStringHashCode26igk1bx568vk as getStringHashCode,
  StringCompanionObject_instance3btc7up7fjjpg as StringCompanionObject_instance,
  LinkedHashMap1zhqxkxv3xnkl as LinkedHashMap,
  ArrayList3it5z8td81qkl as ArrayList,
  isInterface3d6p8outrmvmk as isInterface,
  IllegalStateExceptionkoljg5n0nrlr as IllegalStateException,
  KProperty1ca4yb4wlo496 as KProperty1,
  getPropertyCallableRef3hckxc0xueiaj as getPropertyCallableRef,
  constructCallableReference23y65rf941mch as constructCallableReference,
  lazy2hsh8ze7j6ikd as lazy,
  protoOf180f3jzyo7rfj as protoOf,
  captureStack1fzi4aczwc4hg as captureStack,
  charSequenceSubSequence1iwpdba8s3jc7 as charSequenceSubSequence,
  coerceAtLeast2bkz8m9ik7hep as coerceAtLeast,
  coerceAtMost322komnqp70ag as coerceAtMost,
  isBlank1dvkhjjvox3p0 as isBlank,
  Collection1k04j3hzsbod0 as Collection,
  singleOrNullrknfaxokm1sl as singleOrNull,
  emptyMapr06gerzljqtm as emptyMap,
  getValue48kllevslyh6 as getValue,
  copyOf2ng0t8oizk6it as copyOf,
  arrayCopytctsywo3h7gj as arrayCopy,
  DeepRecursiveFunction3r49v8igsve1g as DeepRecursiveFunction,
  invoke246lvi6tzooz1 as invoke,
  getKClass3t8tygqu4lcxf as getKClass,
  ensureNotNull1e947j3ixpazm as ensureNotNull,
  substringBefore3n7kj60w69hju as substringBefore,
  removeSuffix3d61x5lsuvuho as removeSuffix,
  substringAfter1hku067gwr5ve as substringAfter,
  contains3ue2qo8xhmpf1 as contains,
  plus17rl43at52ays as plus,
  convertToByte1epqhkuyxuz5a as convertToByte,
  fromInt1lka3ktyu79a4 as fromInt,
  equalsLong28bsrfhwvd686 as equalsLong,
  convertToShortvtefcftm709c as convertToShort,
  convertToIntofdoxh9bstof as convertToInt,
  isFinite1tx0gn65nl9tj as isFinite,
  isFinite2t9l5a275mxm6 as isFinite_0,
  charCodeAt1yspne1d8erbm as charCodeAt,
  toUInt21lx0mz8wkp7c as toUInt,
  _UInt___get_data__impl__f0vqqw18g8a2o14g87q as _UInt___get_data__impl__f0vqqw,
  toULong266mnyksbttkw as toULong,
  _ULong___get_data__impl__fggpzb35t7vg7og3i8u as _ULong___get_data__impl__fggpzb,
  toUByteh6p4wmqswkrs as toUByte,
  _UByte___get_data__impl__jof9qryxuf3cmdpzyk as _UByte___get_data__impl__jof9qr,
  toUShort7yqspfnhrot4 as toUShort,
  _UShort___get_data__impl__g02451joe1vsk2vach as _UShort___get_data__impl__g0245,
  Companion_getInstance2bqk1h54tdzgh as Companion_getInstance,
  Companion_getInstancehe6v7kxreu2f as Companion_getInstance_0,
  Companion_getInstance29en1y99grgx1 as Companion_getInstance_1,
  Companion_getInstancehpp5w6ty1u0b as Companion_getInstance_2,
  setOf45ia9pnfhe90 as setOf,
  Char__toInt_impl_vasixd1ka89vowck9tn as Char__toInt_impl_vasixd,
  numberToChar93r9buh19yek as numberToChar,
  equals2v6cggk171b6e as equals_0,
  toString336ienavfnzn0 as toString_1,
  toByte4i43936u611k as toByte,
  noWhenBranchMatchedException2a6r7ubxgky5j as noWhenBranchMatchedException,
  startsWith26w8qjqapeeq6 as startsWith,
  numberRangeToNumber25vse2rgp6rs8 as numberRangeToNumber,
  ClosedRangehokgr73im9z3 as ClosedRange,
  contains2c50nlxg7en7o as contains_0,
  single29ec4rh52687r as single,
  Char19o2r8palgjof as Char,
  emptySetcxexqki71qfa as emptySet,
  plus1ogy4liedzq5j as plus_0,
  toInt2q8uldh7sc951 as toInt,
  toList3jhuyej2anx2q as toList,
  toNumberlmbpvqo27r53 as toNumber,
  last1vo29oleiqj36 as last,
  removeLast3759euu1xvfa3 as removeLast,
  lastIndexOf2d52xhix5ymjr as lastIndexOf,
  Long2qws0ah9gnpki as Long,
  Char__minus_impl_a2frrh370khreoakmi6 as Char__minus_impl_a2frrh,
  multiply18i3gv3wlmcjg as multiply,
  add85si75olwt6n as add,
  subtract16cg4lfi29fq9 as subtract,
  compare2uud5j30pw5xc as compare,
  numberToLong345n6tb1n1i71 as numberToLong,
  negate12tprdg5pyd5t as negate,
  charArray2ujmm1qusno00 as charArray,
  indexOfwa4w6635jewi as indexOf,
  indexOf1xbs558u7wr52 as indexOf_0,
  substringiqarkczpya5m as substring,
  HashMap1a0ld5kgwhmhv as HashMap,
} from './kotlin-kotlin-stdlib.mjs';
//region block: imports
var imul = Math.imul;
//endregion
//region block: pre-declaration
class Json {
  constructor(configuration, serializersModule) {
    Default_getInstance();
    this.l11_1 = configuration;
    this.m11_1 = serializersModule;
    this.n11_1 = new DescriptorSchemaCache();
  }
  oq() {
    return this.m11_1;
  }
  o11(deserializer, string) {
    var lexer = StringJsonLexer_0(this, string);
    var input = new StreamingJsonDecoder(this, WriteMode_OBJ_getInstance(), lexer, deserializer.om(), null);
    var result = input.yp(deserializer);
    lexer.e12();
    return result;
  }
  p11(deserializer, element) {
    return readJson(this, element, deserializer);
  }
  q11(string) {
    return this.o11(JsonElementSerializer_getInstance(), string);
  }
}
class Default extends Json {
  constructor() {
    Default_instance = null;
    super(new JsonConfiguration(), EmptySerializersModule());
    Default_instance = this;
  }
}
class JsonBuilder {
  constructor(json) {
    this.f12_1 = json.l11_1.z12_1;
    this.g12_1 = json.l11_1.e13_1;
    this.h12_1 = json.l11_1.a13_1;
    this.i12_1 = json.l11_1.b13_1;
    this.j12_1 = json.l11_1.d13_1;
    this.k12_1 = json.l11_1.f13_1;
    this.l12_1 = json.l11_1.g13_1;
    this.m12_1 = json.l11_1.i13_1;
    this.n12_1 = json.l11_1.p13_1;
    this.o12_1 = json.l11_1.k13_1;
    this.p12_1 = json.l11_1.l13_1;
    this.q12_1 = json.l11_1.m13_1;
    this.r12_1 = json.l11_1.n13_1;
    this.s12_1 = json.l11_1.o13_1;
    this.t12_1 = json.l11_1.j13_1;
    this.u12_1 = json.l11_1.c13_1;
    this.v12_1 = json.l11_1.h13_1;
    this.w12_1 = json.oq();
    this.x12_1 = json.l11_1.q13_1;
  }
  y12() {
    if (this.v12_1) {
      // Inline function 'kotlin.require' call
      if (!(this.m12_1 === 'type')) {
        var message = 'Class discriminator should not be specified when array polymorphism is specified';
        throw IllegalArgumentException.r(toString(message));
      }
      // Inline function 'kotlin.require' call
      if (!this.n12_1.equals(ClassDiscriminatorMode_POLYMORPHIC_getInstance())) {
        var message_0 = 'useArrayPolymorphism option can only be used if classDiscriminatorMode in a default POLYMORPHIC state.';
        throw IllegalArgumentException.r(toString(message_0));
      }
    }
    if (!this.j12_1) {
      // Inline function 'kotlin.require' call
      if (!(this.k12_1 === '    ')) {
        var message_1 = 'Indent should not be specified when default printing mode is used';
        throw IllegalArgumentException.r(toString(message_1));
      }
    } else if (!(this.k12_1 === '    ')) {
      var tmp0 = this.k12_1;
      var tmp$ret$6;
      $l$block: {
        // Inline function 'kotlin.text.all' call
        var inductionVariable = 0;
        while (inductionVariable < charSequenceLength(tmp0)) {
          var element = charSequenceGet(tmp0, inductionVariable);
          inductionVariable = inductionVariable + 1 | 0;
          if (!(element === _Char___init__impl__6a9atx(32) || element === _Char___init__impl__6a9atx(9) || element === _Char___init__impl__6a9atx(13) || element === _Char___init__impl__6a9atx(10))) {
            tmp$ret$6 = false;
            break $l$block;
          }
        }
        tmp$ret$6 = true;
      }
      var allWhitespaces = tmp$ret$6;
      // Inline function 'kotlin.require' call
      if (!allWhitespaces) {
        var message_2 = 'Only whitespace, tab, newline and carriage return are allowed as pretty print symbols. Had ' + this.k12_1;
        throw IllegalArgumentException.r(toString(message_2));
      }
    }
    return new JsonConfiguration(this.f12_1, this.h12_1, this.i12_1, this.u12_1, this.j12_1, this.g12_1, this.k12_1, this.l12_1, this.v12_1, this.m12_1, this.t12_1, this.o12_1, this.p12_1, this.q12_1, this.r12_1, this.s12_1, this.n12_1, this.x12_1);
  }
}
class JsonImpl extends Json {
  constructor(configuration, module_0) {
    super(configuration, module_0);
    validateConfiguration(this);
  }
}
class JsonClassDiscriminator {}
class JsonIgnoreUnknownKeys {}
class JsonNames {}
class JsonConfiguration {
  constructor(encodeDefaults, ignoreUnknownKeys, isLenient, allowStructuredMapKeys, prettyPrint, explicitNulls, prettyPrintIndent, coerceInputValues, useArrayPolymorphism, classDiscriminator, allowSpecialFloatingPointValues, useAlternativeNames, namingStrategy, decodeEnumsCaseInsensitive, allowTrailingComma, allowComments, classDiscriminatorMode, exceptionsWithDebugInfo) {
    encodeDefaults = encodeDefaults === VOID ? false : encodeDefaults;
    ignoreUnknownKeys = ignoreUnknownKeys === VOID ? false : ignoreUnknownKeys;
    isLenient = isLenient === VOID ? false : isLenient;
    allowStructuredMapKeys = allowStructuredMapKeys === VOID ? false : allowStructuredMapKeys;
    prettyPrint = prettyPrint === VOID ? false : prettyPrint;
    explicitNulls = explicitNulls === VOID ? true : explicitNulls;
    prettyPrintIndent = prettyPrintIndent === VOID ? '    ' : prettyPrintIndent;
    coerceInputValues = coerceInputValues === VOID ? false : coerceInputValues;
    useArrayPolymorphism = useArrayPolymorphism === VOID ? false : useArrayPolymorphism;
    classDiscriminator = classDiscriminator === VOID ? 'type' : classDiscriminator;
    allowSpecialFloatingPointValues = allowSpecialFloatingPointValues === VOID ? false : allowSpecialFloatingPointValues;
    useAlternativeNames = useAlternativeNames === VOID ? true : useAlternativeNames;
    namingStrategy = namingStrategy === VOID ? null : namingStrategy;
    decodeEnumsCaseInsensitive = decodeEnumsCaseInsensitive === VOID ? false : decodeEnumsCaseInsensitive;
    allowTrailingComma = allowTrailingComma === VOID ? false : allowTrailingComma;
    allowComments = allowComments === VOID ? false : allowComments;
    classDiscriminatorMode = classDiscriminatorMode === VOID ? ClassDiscriminatorMode_POLYMORPHIC_getInstance() : classDiscriminatorMode;
    exceptionsWithDebugInfo = exceptionsWithDebugInfo === VOID ? true : exceptionsWithDebugInfo;
    this.z12_1 = encodeDefaults;
    this.a13_1 = ignoreUnknownKeys;
    this.b13_1 = isLenient;
    this.c13_1 = allowStructuredMapKeys;
    this.d13_1 = prettyPrint;
    this.e13_1 = explicitNulls;
    this.f13_1 = prettyPrintIndent;
    this.g13_1 = coerceInputValues;
    this.h13_1 = useArrayPolymorphism;
    this.i13_1 = classDiscriminator;
    this.j13_1 = allowSpecialFloatingPointValues;
    this.k13_1 = useAlternativeNames;
    this.l13_1 = namingStrategy;
    this.m13_1 = decodeEnumsCaseInsensitive;
    this.n13_1 = allowTrailingComma;
    this.o13_1 = allowComments;
    this.p13_1 = classDiscriminatorMode;
    this.q13_1 = exceptionsWithDebugInfo;
  }
  toString() {
    return 'JsonConfiguration(encodeDefaults=' + this.z12_1 + ', ignoreUnknownKeys=' + this.a13_1 + ', isLenient=' + this.b13_1 + ', ' + ('allowStructuredMapKeys=' + this.c13_1 + ', prettyPrint=' + this.d13_1 + ', explicitNulls=' + this.e13_1 + ', ') + ("prettyPrintIndent='" + this.f13_1 + "', coerceInputValues=" + this.g13_1 + ', useArrayPolymorphism=' + this.h13_1 + ', ') + ("classDiscriminator='" + this.i13_1 + "', allowSpecialFloatingPointValues=" + this.j13_1 + ', ') + ('useAlternativeNames=' + this.k13_1 + ', namingStrategy=' + toString_0(this.l13_1) + ', decodeEnumsCaseInsensitive=' + this.m13_1 + ', ') + ('allowTrailingComma=' + this.n13_1 + ', allowComments=' + this.o13_1 + ', classDiscriminatorMode=' + this.p13_1.toString() + ', exceptionsWithDebugInfo=' + this.q13_1 + ')');
  }
}
class ClassDiscriminatorMode extends Enum {}
class JsonDecoder {}
class Companion {}
class JsonElement {}
class JsonArray extends JsonElement {
  constructor(content) {
    super();
    this.t13_1 = content;
  }
  equals(other) {
    return equals(this.t13_1, other);
  }
  hashCode() {
    return hashCode(this.t13_1);
  }
  toString() {
    return joinToString(this.t13_1, ',', '[', ']');
  }
  a1() {
    return this.t13_1.a1();
  }
  u13(element) {
    return this.t13_1.e2(element);
  }
  e2(element) {
    if (!(element instanceof JsonElement))
      return false;
    return this.u13(element instanceof JsonElement ? element : THROW_CCE());
  }
  w() {
    return this.t13_1.w();
  }
  z(index) {
    return this.t13_1.z(index);
  }
  d1(index) {
    return this.t13_1.d1(index);
  }
  b1() {
    return this.t13_1.b1();
  }
}
class Companion_0 {}
class Companion_1 {}
class JsonObject extends JsonElement {
  constructor(content) {
    super();
    this.v13_1 = content;
  }
  equals(other) {
    return equals(this.v13_1, other);
  }
  hashCode() {
    return hashCode(this.v13_1);
  }
  toString() {
    var tmp = this.v13_1.n2();
    return joinToString(tmp, ',', '{', '}', VOID, VOID, JsonObject$toString$lambda);
  }
  a1() {
    return this.v13_1.a1();
  }
  w13(key) {
    return this.v13_1.i2(key);
  }
  i2(key) {
    if (!(!(key == null) ? typeof key === 'string' : false))
      return false;
    return this.w13((!(key == null) ? typeof key === 'string' : false) ? key : THROW_CCE());
  }
  x13(key) {
    return this.v13_1.k2(key);
  }
  k2(key) {
    if (!(!(key == null) ? typeof key === 'string' : false))
      return null;
    return this.x13((!(key == null) ? typeof key === 'string' : false) ? key : THROW_CCE());
  }
  b1() {
    return this.v13_1.b1();
  }
  l2() {
    return this.v13_1.l2();
  }
  m2() {
    return this.v13_1.m2();
  }
  n2() {
    return this.v13_1.n2();
  }
}
class Companion_2 {}
class JsonPrimitive extends JsonElement {
  toString() {
    return this.y13();
  }
}
class JsonNull extends JsonPrimitive {
  constructor() {
    JsonNull_instance = null;
    super();
    JsonNull_instance = this;
    this.z13_1 = 'null';
  }
  y13() {
    return this.z13_1;
  }
}
class JsonLiteral extends JsonPrimitive {
  constructor(body, isString, coerceToInlineType) {
    coerceToInlineType = coerceToInlineType === VOID ? null : coerceToInlineType;
    super();
    this.a14_1 = isString;
    this.b14_1 = coerceToInlineType;
    this.c14_1 = toString(body);
    if (!(this.b14_1 == null)) {
      // Inline function 'kotlin.require' call
      // Inline function 'kotlin.require' call
      if (!this.b14_1.yn()) {
        var message = 'Failed requirement.';
        throw IllegalArgumentException.r(toString(message));
      }
    }
  }
  y13() {
    return this.c14_1;
  }
  toString() {
    var tmp;
    if (this.a14_1) {
      // Inline function 'kotlin.text.buildString' call
      // Inline function 'kotlin.apply' call
      var this_0 = StringBuilder.t();
      printQuoted(this_0, this.c14_1);
      tmp = this_0.toString();
    } else {
      tmp = this.c14_1;
    }
    return tmp;
  }
  equals(other) {
    if (this === other)
      return true;
    if (other == null || !getKClassFromExpression(this).equals(getKClassFromExpression(other)))
      return false;
    if (!(other instanceof JsonLiteral))
      THROW_CCE();
    if (!(this.a14_1 === other.a14_1))
      return false;
    if (!(this.c14_1 === other.c14_1))
      return false;
    return true;
  }
  hashCode() {
    var result = getBooleanHashCode(this.a14_1);
    result = imul(31, result) + getStringHashCode(this.c14_1) | 0;
    return result;
  }
}
class JsonObjectBuilder {
  constructor() {
    var tmp = this;
    // Inline function 'kotlin.collections.linkedMapOf' call
    tmp.e14_1 = LinkedHashMap.ea();
  }
  f14(key, element) {
    return this.e14_1.o2(key, element);
  }
  y12() {
    return new JsonObject(this.e14_1);
  }
}
class JsonArrayBuilder {
  constructor() {
    var tmp = this;
    // Inline function 'kotlin.collections.mutableListOf' call
    tmp.g14_1 = ArrayList.n();
  }
  h14(element) {
    // Inline function 'kotlin.collections.plusAssign' call
    this.g14_1.u(element);
    return true;
  }
  y12() {
    return new JsonArray(this.g14_1);
  }
}
class JsonArrayDescriptor {
  constructor() {
    JsonArrayDescriptor_instance = this;
    this.i14_1 = ListSerializer(JsonElementSerializer_getInstance()).om();
    this.j14_1 = 'kotlinx.serialization.json.JsonArray';
  }
  wn() {
    return this.j14_1;
  }
  bo(index) {
    return this.i14_1.bo(index);
  }
  co(name) {
    return this.i14_1.co(name);
  }
  do(index) {
    return this.i14_1.do(index);
  }
  eo(index) {
    return this.i14_1.eo(index);
  }
  fo(index) {
    return this.i14_1.fo(index);
  }
  xn() {
    return this.i14_1.xn();
  }
  qn() {
    return this.i14_1.qn();
  }
  yn() {
    return this.i14_1.yn();
  }
  zn() {
    return this.i14_1.zn();
  }
  ao() {
    return this.i14_1.ao();
  }
}
class JsonArraySerializer {
  constructor() {
    JsonArraySerializer_instance = this;
    this.k14_1 = JsonArrayDescriptor_getInstance();
  }
  om() {
    return this.k14_1;
  }
  pm(decoder) {
    verify(decoder);
    return new JsonArray(ListSerializer(JsonElementSerializer_getInstance()).pm(decoder));
  }
}
class JsonElementSerializer {
  constructor() {
    JsonElementSerializer_instance = this;
    var tmp = this;
    var tmp_0 = SEALED_getInstance();
    tmp.p14_1 = buildSerialDescriptor('kotlinx.serialization.json.JsonElement', tmp_0, [], JsonElementSerializer$descriptor$lambda);
  }
  om() {
    return this.p14_1;
  }
  pm(decoder) {
    var input = asJsonDecoder(decoder);
    return input.s13();
  }
}
class JsonObjectDescriptor {
  constructor() {
    JsonObjectDescriptor_instance = this;
    this.q14_1 = MapSerializer(serializer(StringCompanionObject_instance), JsonElementSerializer_getInstance()).om();
    this.r14_1 = 'kotlinx.serialization.json.JsonObject';
  }
  wn() {
    return this.r14_1;
  }
  bo(index) {
    return this.q14_1.bo(index);
  }
  co(name) {
    return this.q14_1.co(name);
  }
  do(index) {
    return this.q14_1.do(index);
  }
  eo(index) {
    return this.q14_1.eo(index);
  }
  fo(index) {
    return this.q14_1.fo(index);
  }
  xn() {
    return this.q14_1.xn();
  }
  qn() {
    return this.q14_1.qn();
  }
  yn() {
    return this.q14_1.yn();
  }
  zn() {
    return this.q14_1.zn();
  }
  ao() {
    return this.q14_1.ao();
  }
}
class JsonObjectSerializer {
  constructor() {
    JsonObjectSerializer_instance = this;
    this.o14_1 = JsonObjectDescriptor_getInstance();
  }
  om() {
    return this.o14_1;
  }
  pm(decoder) {
    verify(decoder);
    return new JsonObject(MapSerializer(serializer(StringCompanionObject_instance), JsonElementSerializer_getInstance()).pm(decoder));
  }
}
class JsonPrimitiveSerializer {
  constructor() {
    JsonPrimitiveSerializer_instance = this;
    this.l14_1 = buildSerialDescriptor('kotlinx.serialization.json.JsonPrimitive', STRING_getInstance(), []);
  }
  om() {
    return this.l14_1;
  }
  pm(decoder) {
    var jsonDecoder = asJsonDecoder(decoder);
    var result = jsonDecoder.s13();
    if (!(result instanceof JsonPrimitive)) {
      // Inline function 'kotlinx.serialization.json.internal.decodingExceptionOf' call
      var shortMessage = 'Unexpected JSON element, expected JsonPrimitive, had ' + toString(getKClassFromExpression(result));
      var tmp;
      if (jsonDecoder.r13().l11_1.q13_1) {
        var tmp$ret$3 = toString(result);
        tmp = toString(minify(tmp$ret$3));
      } else {
        tmp = null;
      }
      var inputValue = tmp;
      throw JsonDecodingException.e15(access$formatDecodingException$tJsonExceptionsKt(-1, shortMessage, null, null, inputValue), shortMessage, -1, null, inputValue, null);
    }
    return result;
  }
}
class JsonNullSerializer {
  constructor() {
    JsonNullSerializer_instance = this;
    this.m14_1 = buildSerialDescriptor('kotlinx.serialization.json.JsonNull', ENUM_getInstance(), []);
  }
  om() {
    return this.m14_1;
  }
  pm(decoder) {
    verify(decoder);
    if (decoder.kp()) {
      throw decodingExceptionOf("Expected 'null' literal");
    }
    decoder.lp();
    return JsonNull_getInstance();
  }
}
class JsonLiteralSerializer {
  constructor() {
    JsonLiteralSerializer_instance = this;
    this.n14_1 = PrimitiveSerialDescriptor('kotlinx.serialization.json.JsonLiteral', STRING_getInstance());
  }
  om() {
    return this.n14_1;
  }
  pm(decoder) {
    var jsonDecoder = asJsonDecoder(decoder);
    var result = jsonDecoder.s13();
    if (!(result instanceof JsonLiteral)) {
      // Inline function 'kotlinx.serialization.json.internal.decodingExceptionOf' call
      var shortMessage = 'Unexpected JSON element, expected JsonLiteral, had ' + toString(getKClassFromExpression(result));
      var tmp;
      if (jsonDecoder.r13().l11_1.q13_1) {
        var tmp$ret$3 = toString(result);
        tmp = toString(minify(tmp$ret$3));
      } else {
        tmp = null;
      }
      var inputValue = tmp;
      throw JsonDecodingException.e15(access$formatDecodingException$tJsonExceptionsKt(-1, shortMessage, null, null, inputValue), shortMessage, -1, null, inputValue, null);
    }
    return result;
  }
}
class defer$1 {
  constructor($deferred) {
    this.f15_1 = lazy($deferred);
  }
  wn() {
    return _get_original__l7ku1m(this).wn();
  }
  xn() {
    return _get_original__l7ku1m(this).xn();
  }
  zn() {
    return _get_original__l7ku1m(this).zn();
  }
  bo(index) {
    return _get_original__l7ku1m(this).bo(index);
  }
  co(name) {
    return _get_original__l7ku1m(this).co(name);
  }
  do(index) {
    return _get_original__l7ku1m(this).do(index);
  }
  eo(index) {
    return _get_original__l7ku1m(this).eo(index);
  }
  fo(index) {
    return _get_original__l7ku1m(this).fo(index);
  }
}
class JsonException extends SerializationException {
  static m15(message) {
    var $this = this.cn(message);
    captureStack($this, $this.l15_1);
    $this.k15_1 = message;
    delete $this.message;
    return $this;
  }
  ab() {
    return this.k15_1;
  }
  get message() {
    return this.ab();
  }
}
class JsonDecodingException extends JsonException {
  constructor(fullMessage, shortMessage, offset, path, input, hint) {
    return new.target.e15(fullMessage, shortMessage, offset, path, input, hint);
  }
  static e15(fullMessage, shortMessage, offset, path, input, hint) {
    var $this = this.m15(fullMessage);
    captureStack($this, $this.d15_1);
    $this.y14_1 = shortMessage;
    $this.z14_1 = offset;
    $this.a15_1 = path;
    $this.b15_1 = input;
    $this.c15_1 = hint;
    return $this;
  }
}
class JsonEncodingException extends JsonException {
  constructor(shortMessage, classSerialName, hint) {
    return new.target.x15(shortMessage, classSerialName, hint);
  }
  static x15(shortMessage, classSerialName, hint) {
    classSerialName = classSerialName === VOID ? null : classSerialName;
    hint = hint === VOID ? null : hint;
    var $this = this.m15(formatEncodingException(shortMessage, hint));
    captureStack($this, $this.w15_1);
    $this.t15_1 = shortMessage;
    $this.u15_1 = classSerialName;
    $this.v15_1 = hint;
    return $this;
  }
}
class JsonElementMarker {
  constructor(descriptor) {
    var tmp = this;
    tmp.y15_1 = new ElementMarker(descriptor, JsonElementMarker$readIfAbsent$ref(this));
    this.z15_1 = false;
  }
  a16(index) {
    this.y15_1.dt(index);
  }
  b16() {
    return this.y15_1.et();
  }
}
class Tombstone {}
class RedactedKey {}
class JsonPath {
  constructor(configuration) {
    this.i16_1 = configuration;
    var tmp = this;
    // Inline function 'kotlin.arrayOfNulls' call
    tmp.j16_1 = Array(8);
    var tmp_0 = this;
    var tmp_1 = 0;
    var tmp_2 = new Int32Array(8);
    while (tmp_1 < 8) {
      tmp_2[tmp_1] = -1;
      tmp_1 = tmp_1 + 1 | 0;
    }
    tmp_0.k16_1 = tmp_2;
    this.l16_1 = -1;
  }
  m16(sd) {
    this.l16_1 = this.l16_1 + 1 | 0;
    var depth = this.l16_1;
    if (depth === this.j16_1.length) {
      resize(this);
    }
    this.j16_1[depth] = sd;
  }
  n16(index) {
    this.k16_1[this.l16_1] = index;
  }
  o16(key) {
    var tmp;
    if (!(this.k16_1[this.l16_1] === -2)) {
      this.l16_1 = this.l16_1 + 1 | 0;
      tmp = this.l16_1 === this.j16_1.length;
    } else {
      tmp = false;
    }
    if (tmp) {
      resize(this);
    }
    this.j16_1[this.l16_1] = this.i16_1.q13_1 ? key : RedactedKey_instance;
    this.k16_1[this.l16_1] = -2;
  }
  p16() {
    if (this.k16_1[this.l16_1] === -2) {
      this.j16_1[this.l16_1] = Tombstone_instance;
    }
  }
  q16() {
    var depth = this.l16_1;
    if (this.k16_1[depth] === -2) {
      this.k16_1[depth] = -1;
      this.l16_1 = this.l16_1 - 1 | 0;
    }
    if (!(this.l16_1 === -1)) {
      this.l16_1 = this.l16_1 - 1 | 0;
    }
  }
  r16() {
    // Inline function 'kotlin.text.buildString' call
    // Inline function 'kotlin.apply' call
    var this_0 = StringBuilder.t();
    this_0.s9('$');
    // Inline function 'kotlin.repeat' call
    var times = this.l16_1 + 1 | 0;
    var inductionVariable = 0;
    if (inductionVariable < times)
      do {
        var index = inductionVariable;
        inductionVariable = inductionVariable + 1 | 0;
        var element = this.j16_1[index];
        if (!(element == null) ? isInterface(element, SerialDescriptor) : false) {
          if (equals(element.xn(), LIST_getInstance())) {
            if (!(this.k16_1[index] === -1)) {
              this_0.s9('[');
              this_0.ud(this.k16_1[index]);
              this_0.s9(']');
            }
          } else {
            var idx = this.k16_1[index];
            if (idx >= 0) {
              this_0.s9('.');
              this_0.s9(element.bo(idx));
            }
          }
        } else {
          if (element === RedactedKey_instance) {
            this_0.s9('[<debug info disabled>]');
          } else {
            if (!(element === Tombstone_instance)) {
              this_0.s9('[');
              this_0.s9("'");
              this_0.r9(element);
              this_0.s9("'");
              this_0.s9(']');
            }
          }
        }
      }
       while (inductionVariable < times);
    return this_0.toString();
  }
  toString() {
    return this.r16();
  }
}
class JsonSerializersModuleValidator {
  constructor(configuration) {
    this.s16_1 = configuration.h13_1;
    this.t16_1 = !configuration.p13_1.equals(ClassDiscriminatorMode_NONE_getInstance());
  }
  f11(kClass, provider) {
  }
  i11(baseClass, actualClass, actualSerializer) {
    var descriptor = actualSerializer.om();
    checkKind(this, descriptor, actualClass);
  }
  j11(baseClass, defaultSerializerProvider) {
  }
  k11(baseClass, defaultDeserializerProvider) {
  }
}
class JsonTreeReader {
  constructor(configuration, lexer) {
    this.u16_1 = lexer;
    this.v16_1 = configuration.b13_1;
    this.w16_1 = configuration.n13_1;
    this.x16_1 = 0;
  }
  d17() {
    var token = this.u16_1.z16();
    var tmp;
    if (token === 1) {
      tmp = readValue(this, true);
    } else if (token === 0) {
      tmp = readValue(this, false);
    } else if (token === 6) {
      var tmp_0;
      this.x16_1 = this.x16_1 + 1 | 0;
      if (this.x16_1 === 200) {
        tmp_0 = readDeepRecursive(this);
      } else {
        tmp_0 = readObject(this);
      }
      var result = tmp_0;
      this.x16_1 = this.x16_1 - 1 | 0;
      tmp = result;
    } else if (token === 8) {
      tmp = readArray(this);
    } else {
      this.u16_1.d16('Cannot read Json element because of unexpected ' + tokenDescription(token));
    }
    return tmp;
  }
}
class Key {}
class DescriptorSchemaCache {
  constructor() {
    this.e16_1 = createMapForCache(16);
  }
  g17(descriptor, key, value) {
    // Inline function 'kotlin.collections.getOrPut' call
    var this_0 = this.e16_1;
    var value_0 = this_0.k2(descriptor);
    var tmp;
    if (value_0 == null) {
      var answer = createMapForCache(2);
      this_0.o2(descriptor, answer);
      tmp = answer;
    } else {
      tmp = value_0;
    }
    var tmp0 = tmp;
    var tmp2 = key instanceof Key ? key : THROW_CCE();
    // Inline function 'kotlin.collections.set' call
    var value_1 = !(value == null) ? value : THROW_CCE();
    tmp0.o2(tmp2, value_1);
  }
  f16(descriptor, key, defaultValue) {
    var tmp0_safe_receiver = this.h17(descriptor, key);
    if (tmp0_safe_receiver == null)
      null;
    else {
      // Inline function 'kotlin.let' call
      return tmp0_safe_receiver;
    }
    var value = defaultValue();
    this.g17(descriptor, key, value);
    return value;
  }
  h17(descriptor, key) {
    var tmp0_safe_receiver = this.e16_1.k2(descriptor);
    var tmp;
    if (tmp0_safe_receiver == null) {
      tmp = null;
    } else {
      tmp = tmp0_safe_receiver.k2(key instanceof Key ? key : THROW_CCE());
    }
    var tmp_0 = tmp;
    return !(tmp_0 == null) ? tmp_0 : null;
  }
}
class DiscriminatorHolder {
  constructor(discriminatorToSkip) {
    this.i17_1 = discriminatorToSkip;
  }
}
class StreamingJsonDecoder extends AbstractDecoder {
  constructor(json, mode, lexer, descriptor, discriminatorHolder) {
    super();
    this.r11_1 = json;
    this.s11_1 = mode;
    this.t11_1 = lexer;
    this.u11_1 = this.r11_1.oq();
    this.v11_1 = -1;
    this.w11_1 = discriminatorHolder;
    this.x11_1 = this.r11_1.l11_1;
    this.y11_1 = this.x11_1.e13_1 ? null : new JsonElementMarker(descriptor);
  }
  r13() {
    return this.r11_1;
  }
  oq() {
    return this.u11_1;
  }
  s13() {
    return (new JsonTreeReader(this.r11_1.l11_1, this.t11_1)).d17();
  }
  yp(deserializer) {
    try {
      var tmp;
      if (!(deserializer instanceof AbstractPolymorphicSerializer)) {
        tmp = true;
      } else {
        tmp = this.r11_1.l11_1.h13_1;
      }
      if (tmp) {
        return deserializer.pm(this);
      }
      var discriminator = classDiscriminator(deserializer.om(), this.r11_1);
      var tmp0_elvis_lhs = this.t11_1.r17(discriminator, this.x11_1.b13_1);
      var tmp_0;
      if (tmp0_elvis_lhs == null) {
        var tmp2 = isInterface(deserializer, DeserializationStrategy) ? deserializer : THROW_CCE();
        var tmp$ret$0;
        $l$block: {
          // Inline function 'kotlinx.serialization.json.internal.decodeSerializableValuePolymorphic' call
          var tmp_1;
          if (!(tmp2 instanceof AbstractPolymorphicSerializer)) {
            tmp_1 = true;
          } else {
            tmp_1 = this.r13().l11_1.h13_1;
          }
          if (tmp_1) {
            tmp$ret$0 = tmp2.pm(this);
            break $l$block;
          }
          var discriminator_0 = classDiscriminator(tmp2.om(), this.r13());
          var tmp2_0 = this.s13();
          // Inline function 'kotlinx.serialization.json.internal.cast' call
          var serialName = tmp2.om().wn();
          if (!(tmp2_0 instanceof JsonObject)) {
            var tmp2_1 = 'Expected ' + getKClass(JsonObject).jc() + ', but had ' + getKClassFromExpression(tmp2_0).jc() + ' as the serialized body of ' + serialName;
            // Inline function 'kotlinx.serialization.json.internal.decodingExceptionOf' call
            var path = this.t11_1.b12_1.r16();
            var tmp_2;
            if (this.r13().l11_1.q13_1) {
              var tmp$ret$6 = toString(tmp2_0);
              tmp_2 = toString(minify(tmp$ret$6));
            } else {
              tmp_2 = null;
            }
            var inputValue = tmp_2;
            throw JsonDecodingException.e15(access$formatDecodingException$tJsonExceptionsKt(-1, tmp2_1, path, null, inputValue), tmp2_1, -1, path, inputValue, null);
          }
          var jsonTree = tmp2_0;
          var tmp0_safe_receiver = jsonTree.x13(discriminator_0);
          var tmp1_safe_receiver = tmp0_safe_receiver == null ? null : get_jsonPrimitive(tmp0_safe_receiver);
          var type = tmp1_safe_receiver == null ? null : get_contentOrNull(tmp1_safe_receiver);
          var tmp_3;
          try {
            tmp_3 = findPolymorphicSerializer(tmp2, this, type);
          } catch ($p) {
            var tmp_4;
            if ($p instanceof SerializationException) {
              var it = $p;
              // Inline function 'kotlinx.serialization.json.internal.decodingExceptionOf' call
              var shortMessage = ensureNotNull(it.message);
              var tmp_5;
              if (this.r13().l11_1.q13_1) {
                var tmp$ret$10 = jsonTree.toString();
                tmp_5 = toString(minify(tmp$ret$10));
              } else {
                tmp_5 = null;
              }
              var inputValue_0 = tmp_5;
              throw JsonDecodingException.e15(access$formatDecodingException$tJsonExceptionsKt(-1, shortMessage, null, null, inputValue_0), shortMessage, -1, null, inputValue_0, null);
            } else {
              throw $p;
            }
          }
          var tmp_6 = tmp_3;
          var actualSerializer = isInterface(tmp_6, DeserializationStrategy) ? tmp_6 : THROW_CCE();
          tmp$ret$0 = readPolymorphicJson(this.r13(), discriminator_0, jsonTree, actualSerializer);
        }
        return tmp$ret$0;
      } else {
        tmp_0 = tmp0_elvis_lhs;
      }
      var type_0 = tmp_0;
      var tmp_7;
      try {
        tmp_7 = findPolymorphicSerializer(deserializer, this, type_0);
      } catch ($p_0) {
        var tmp_8;
        if ($p_0 instanceof SerializationException) {
          var it_0 = $p_0;
          var message = removeSuffix(substringBefore(ensureNotNull(it_0.message), _Char___init__impl__6a9atx(10)), '.');
          var hint = substringAfter(ensureNotNull(it_0.message), _Char___init__impl__6a9atx(10), '');
          this.t11_1.d16(message, VOID, hint);
        } else {
          throw $p_0;
        }
        tmp_7 = tmp_8;
      }
      var tmp_9 = tmp_7;
      var actualSerializer_0 = isInterface(tmp_9, DeserializationStrategy) ? tmp_9 : THROW_CCE();
      this.w11_1 = new DiscriminatorHolder(discriminator);
      return actualSerializer_0.pm(this);
    } catch ($p_1) {
      if ($p_1 instanceof MissingFieldException) {
        var e = $p_1;
        if (contains(ensureNotNull(e.message), 'at path'))
          throw e;
        throw missingFieldExceptionWithNewMessage(e, plus(e.message, ' at path: ') + this.t11_1.b12_1.r16());
      } else {
        throw $p_1;
      }
    }
  }
  zp(descriptor) {
    var newMode = switchMode(this.r11_1, descriptor);
    this.t11_1.b12_1.m16(descriptor);
    this.t11_1.j17(newMode.u17_1);
    checkLeadingComma(this);
    var tmp;
    switch (newMode.s2_1) {
      case 1:
      case 2:
      case 3:
        tmp = new StreamingJsonDecoder(this.r11_1, newMode, this.t11_1, descriptor, this.w11_1);
        break;
      default:
        var tmp_0;
        if (this.s11_1.equals(newMode) && this.r11_1.l11_1.e13_1) {
          tmp_0 = this;
        } else {
          tmp_0 = new StreamingJsonDecoder(this.r11_1, newMode, this.t11_1, descriptor, this.w11_1);
        }

        tmp = tmp_0;
        break;
    }
    return tmp;
  }
  aq(descriptor) {
    if (descriptor.zn() === 0 && ignoreUnknownKeys(descriptor, this.r11_1)) {
      skipLeftoverElements(this, descriptor);
    }
    if (this.t11_1.k17() && !this.r11_1.l11_1.n13_1) {
      invalidTrailingComma(this.t11_1, '');
    }
    this.t11_1.j17(this.s11_1.v17_1);
    this.t11_1.b12_1.q16();
  }
  kp() {
    var tmp;
    var tmp0_safe_receiver = this.y11_1;
    var tmp1_elvis_lhs = tmp0_safe_receiver == null ? null : tmp0_safe_receiver.z15_1;
    if (!(tmp1_elvis_lhs == null ? false : tmp1_elvis_lhs)) {
      tmp = !this.t11_1.w17();
    } else {
      tmp = false;
    }
    return tmp;
  }
  lp() {
    return null;
  }
  lq(descriptor, index, deserializer, previousValue) {
    var isMapKey = this.s11_1.equals(WriteMode_MAP_getInstance()) && (index & 1) === 0;
    if (isMapKey) {
      this.t11_1.b12_1.p16();
    }
    var value = super.lq(descriptor, index, deserializer, previousValue);
    if (isMapKey) {
      this.t11_1.b12_1.o16(value);
    }
    return value;
  }
  qq(descriptor) {
    var index;
    switch (this.s11_1.s2_1) {
      case 0:
        index = decodeObjectIndex(this, descriptor);
        break;
      case 2:
        index = decodeMapIndex(this);
        break;
      default:
        index = decodeListIndex(this);
        break;
    }
    if (!this.s11_1.equals(WriteMode_MAP_getInstance())) {
      this.t11_1.b12_1.n16(index);
    }
    return index;
  }
  mp() {
    return this.t11_1.x17();
  }
  np() {
    var value = this.t11_1.y17();
    if (!equalsLong(value, fromInt(convertToByte(value)))) {
      this.t11_1.d16("Failed to parse byte for input '" + value.toString() + "'");
    }
    return convertToByte(value);
  }
  op() {
    var value = this.t11_1.y17();
    if (!equalsLong(value, fromInt(convertToShort(value)))) {
      this.t11_1.d16("Failed to parse short for input '" + value.toString() + "'");
    }
    return convertToShort(value);
  }
  pp() {
    var value = this.t11_1.y17();
    if (!equalsLong(value, fromInt(convertToInt(value)))) {
      this.t11_1.d16("Failed to parse int for input '" + value.toString() + "'");
    }
    return convertToInt(value);
  }
  qp() {
    return this.t11_1.y17();
  }
  rp() {
    var tmp0 = this.t11_1;
    var tmp$ret$0;
    $l$block: {
      // Inline function 'kotlinx.serialization.json.internal.parseString' call
      var input = tmp0.c17();
      try {
        // Inline function 'kotlin.text.toFloat' call
        // Inline function 'kotlin.js.unsafeCast' call
        // Inline function 'kotlin.js.asDynamic' call
        tmp$ret$0 = toDouble(input);
        break $l$block;
      } catch ($p) {
        if ($p instanceof IllegalArgumentException) {
          var e = $p;
          tmp0.d16("Failed to parse type '" + 'float' + "' for input '" + input + "'");
        } else {
          throw $p;
        }
      }
    }
    var result = tmp$ret$0;
    var specialFp = this.r11_1.l11_1.j13_1;
    if (specialFp || isFinite(result))
      return result;
    throwInvalidFloatingPointDecoded(this.t11_1, result);
  }
  sp() {
    var tmp0 = this.t11_1;
    var tmp$ret$0;
    $l$block: {
      // Inline function 'kotlinx.serialization.json.internal.parseString' call
      var input = tmp0.c17();
      try {
        tmp$ret$0 = toDouble(input);
        break $l$block;
      } catch ($p) {
        if ($p instanceof IllegalArgumentException) {
          var e = $p;
          tmp0.d16("Failed to parse type '" + 'double' + "' for input '" + input + "'");
        } else {
          throw $p;
        }
      }
    }
    var result = tmp$ret$0;
    var specialFp = this.r11_1.l11_1.j13_1;
    if (specialFp || isFinite_0(result))
      return result;
    throwInvalidFloatingPointDecoded(this.t11_1, result);
  }
  tp() {
    var string = this.t11_1.c17();
    if (!(string.length === 1)) {
      this.t11_1.d16("Expected single char, but got '" + string + "'");
    }
    return charCodeAt(string, 0);
  }
  up() {
    var tmp;
    if (this.x11_1.b13_1) {
      tmp = this.t11_1.q17();
    } else {
      tmp = this.t11_1.b17();
    }
    return tmp;
  }
  wp(descriptor) {
    return get_isUnsignedNumber(descriptor) ? new JsonDecoderForUnsignedTypes(this.t11_1, this.r11_1) : super.wp(descriptor);
  }
  vp(enumDescriptor) {
    return getJsonNameIndexOrThrow(enumDescriptor, this.r11_1, this.up(), ' at path ' + this.t11_1.b12_1.r16());
  }
}
class JsonDecoderForUnsignedTypes extends AbstractDecoder {
  constructor(lexer, json) {
    super();
    this.z17_1 = lexer;
    this.a18_1 = json.oq();
  }
  oq() {
    return this.a18_1;
  }
  qq(descriptor) {
    // Inline function 'kotlin.error' call
    var message = 'unsupported';
    throw IllegalStateException.j3(toString(message));
  }
  pp() {
    var tmp0 = this.z17_1;
    var tmp$ret$0;
    $l$block: {
      // Inline function 'kotlinx.serialization.json.internal.parseString' call
      var input = tmp0.c17();
      try {
        // Inline function 'kotlin.UInt.toInt' call
        var this_0 = toUInt(input);
        tmp$ret$0 = _UInt___get_data__impl__f0vqqw(this_0);
        break $l$block;
      } catch ($p) {
        if ($p instanceof IllegalArgumentException) {
          var e = $p;
          tmp0.d16("Failed to parse type '" + 'UInt' + "' for input '" + input + "'");
        } else {
          throw $p;
        }
      }
    }
    return tmp$ret$0;
  }
  qp() {
    var tmp0 = this.z17_1;
    var tmp$ret$0;
    $l$block: {
      // Inline function 'kotlinx.serialization.json.internal.parseString' call
      var input = tmp0.c17();
      try {
        // Inline function 'kotlin.ULong.toLong' call
        var this_0 = toULong(input);
        tmp$ret$0 = _ULong___get_data__impl__fggpzb(this_0);
        break $l$block;
      } catch ($p) {
        if ($p instanceof IllegalArgumentException) {
          var e = $p;
          tmp0.d16("Failed to parse type '" + 'ULong' + "' for input '" + input + "'");
        } else {
          throw $p;
        }
      }
    }
    return tmp$ret$0;
  }
  np() {
    var tmp0 = this.z17_1;
    var tmp$ret$0;
    $l$block: {
      // Inline function 'kotlinx.serialization.json.internal.parseString' call
      var input = tmp0.c17();
      try {
        // Inline function 'kotlin.UByte.toByte' call
        var this_0 = toUByte(input);
        tmp$ret$0 = _UByte___get_data__impl__jof9qr(this_0);
        break $l$block;
      } catch ($p) {
        if ($p instanceof IllegalArgumentException) {
          var e = $p;
          tmp0.d16("Failed to parse type '" + 'UByte' + "' for input '" + input + "'");
        } else {
          throw $p;
        }
      }
    }
    return tmp$ret$0;
  }
  op() {
    var tmp0 = this.z17_1;
    var tmp$ret$0;
    $l$block: {
      // Inline function 'kotlinx.serialization.json.internal.parseString' call
      var input = tmp0.c17();
      try {
        // Inline function 'kotlin.UShort.toShort' call
        var this_0 = toUShort(input);
        tmp$ret$0 = _UShort___get_data__impl__g0245(this_0);
        break $l$block;
      } catch ($p) {
        if ($p instanceof IllegalArgumentException) {
          var e = $p;
          tmp0.d16("Failed to parse type '" + 'UShort' + "' for input '" + input + "'");
        } else {
          throw $p;
        }
      }
    }
    return tmp$ret$0;
  }
}
class AbstractJsonTreeDecoder extends NamedValueDecoder {
  constructor(json, value, polymorphicDiscriminator) {
    polymorphicDiscriminator = polymorphicDiscriminator === VOID ? null : polymorphicDiscriminator;
    super();
    this.d18_1 = json;
    this.e18_1 = value;
    this.f18_1 = polymorphicDiscriminator;
    this.g18_1 = this.r13().l11_1;
  }
  r13() {
    return this.d18_1;
  }
  h2() {
    return this.e18_1;
  }
  oq() {
    return this.r13().oq();
  }
  i18() {
    var tmp0_safe_receiver = this.vz();
    var tmp;
    if (tmp0_safe_receiver == null) {
      tmp = null;
    } else {
      // Inline function 'kotlin.let' call
      tmp = this.j18(tmp0_safe_receiver);
    }
    var tmp1_elvis_lhs = tmp;
    return tmp1_elvis_lhs == null ? this.h2() : tmp1_elvis_lhs;
  }
  h18(currentTag) {
    return this.xz() + ('.' + currentTag);
  }
  s13() {
    return this.i18();
  }
  yp(deserializer) {
    var tmp$ret$0;
    $l$block: {
      // Inline function 'kotlinx.serialization.json.internal.decodeSerializableValuePolymorphic' call
      var tmp;
      if (!(deserializer instanceof AbstractPolymorphicSerializer)) {
        tmp = true;
      } else {
        tmp = this.r13().l11_1.h13_1;
      }
      if (tmp) {
        tmp$ret$0 = deserializer.pm(this);
        break $l$block;
      }
      var discriminator = classDiscriminator(deserializer.om(), this.r13());
      var tmp2 = this.s13();
      // Inline function 'kotlinx.serialization.json.internal.cast' call
      var serialName = deserializer.om().wn();
      if (!(tmp2 instanceof JsonObject)) {
        var tmp2_0 = 'Expected ' + getKClass(JsonObject).jc() + ', but had ' + getKClassFromExpression(tmp2).jc() + ' as the serialized body of ' + serialName;
        // Inline function 'kotlinx.serialization.json.internal.decodingExceptionOf' call
        var path = this.xz();
        var tmp_0;
        if (this.r13().l11_1.q13_1) {
          var tmp$ret$6 = toString(tmp2);
          tmp_0 = toString(minify(tmp$ret$6));
        } else {
          tmp_0 = null;
        }
        var inputValue = tmp_0;
        throw JsonDecodingException.e15(access$formatDecodingException$tJsonExceptionsKt(-1, tmp2_0, path, null, inputValue), tmp2_0, -1, path, inputValue, null);
      }
      var jsonTree = tmp2;
      var tmp0_safe_receiver = jsonTree.x13(discriminator);
      var tmp1_safe_receiver = tmp0_safe_receiver == null ? null : get_jsonPrimitive(tmp0_safe_receiver);
      var type = tmp1_safe_receiver == null ? null : get_contentOrNull(tmp1_safe_receiver);
      var tmp_1;
      try {
        tmp_1 = findPolymorphicSerializer(deserializer, this, type);
      } catch ($p) {
        var tmp_2;
        if ($p instanceof SerializationException) {
          var it = $p;
          // Inline function 'kotlinx.serialization.json.internal.decodingExceptionOf' call
          var shortMessage = ensureNotNull(it.message);
          var tmp_3;
          if (this.r13().l11_1.q13_1) {
            var tmp$ret$10 = jsonTree.toString();
            tmp_3 = toString(minify(tmp$ret$10));
          } else {
            tmp_3 = null;
          }
          var inputValue_0 = tmp_3;
          throw JsonDecodingException.e15(access$formatDecodingException$tJsonExceptionsKt(-1, shortMessage, null, null, inputValue_0), shortMessage, -1, null, inputValue_0, null);
        } else {
          throw $p;
        }
      }
      var tmp_4 = tmp_1;
      var actualSerializer = isInterface(tmp_4, DeserializationStrategy) ? tmp_4 : THROW_CCE();
      tmp$ret$0 = readPolymorphicJson(this.r13(), discriminator, jsonTree, actualSerializer);
    }
    return tmp$ret$0;
  }
  wz(parentName, childName) {
    return childName;
  }
  zp(descriptor) {
    var currentObject = this.i18();
    var tmp0_subject = descriptor.xn();
    var tmp;
    var tmp_0;
    if (equals(tmp0_subject, LIST_getInstance())) {
      tmp_0 = true;
    } else {
      tmp_0 = tmp0_subject instanceof PolymorphicKind;
    }
    if (tmp_0) {
      var tmp_1 = this.r13();
      // Inline function 'kotlinx.serialization.json.internal.AbstractJsonTreeDecoder.cast' call
      // Inline function 'kotlinx.serialization.json.internal.cast' call
      var serialName = descriptor.wn();
      if (!(currentObject instanceof JsonArray)) {
        var tmp2 = 'Expected ' + getKClass(JsonArray).jc() + ', but had ' + getKClassFromExpression(currentObject).jc() + ' as the serialized body of ' + serialName;
        // Inline function 'kotlinx.serialization.json.internal.decodingExceptionOf' call
        var path = this.xz();
        var tmp_2;
        if (this.r13().l11_1.q13_1) {
          var tmp$ret$6 = toString(currentObject);
          tmp_2 = toString(minify(tmp$ret$6));
        } else {
          tmp_2 = null;
        }
        var inputValue = tmp_2;
        throw JsonDecodingException.e15(access$formatDecodingException$tJsonExceptionsKt(-1, tmp2, path, null, inputValue), tmp2, -1, path, inputValue, null);
      }
      tmp = new JsonTreeListDecoder(tmp_1, currentObject);
    } else {
      if (equals(tmp0_subject, MAP_getInstance())) {
        // Inline function 'kotlinx.serialization.json.internal.selectMapMode' call
        var this_0 = this.r13();
        var keyDescriptor = carrierDescriptor(descriptor.eo(0), this_0.oq());
        var keyKind = keyDescriptor.xn();
        var tmp_3;
        var tmp_4;
        if (keyKind instanceof PrimitiveKind) {
          tmp_4 = true;
        } else {
          tmp_4 = equals(keyKind, ENUM_getInstance());
        }
        if (tmp_4) {
          var tmp_5 = this.r13();
          // Inline function 'kotlinx.serialization.json.internal.AbstractJsonTreeDecoder.cast' call
          // Inline function 'kotlinx.serialization.json.internal.cast' call
          var serialName_0 = descriptor.wn();
          if (!(currentObject instanceof JsonObject)) {
            var tmp2_0 = 'Expected ' + getKClass(JsonObject).jc() + ', but had ' + getKClassFromExpression(currentObject).jc() + ' as the serialized body of ' + serialName_0;
            // Inline function 'kotlinx.serialization.json.internal.decodingExceptionOf' call
            var path_0 = this.xz();
            var tmp_6;
            if (this.r13().l11_1.q13_1) {
              var tmp$ret$15 = toString(currentObject);
              tmp_6 = toString(minify(tmp$ret$15));
            } else {
              tmp_6 = null;
            }
            var inputValue_0 = tmp_6;
            throw JsonDecodingException.e15(access$formatDecodingException$tJsonExceptionsKt(-1, tmp2_0, path_0, null, inputValue_0), tmp2_0, -1, path_0, inputValue_0, null);
          }
          tmp_3 = new JsonTreeMapDecoder(tmp_5, currentObject);
        } else {
          if (this_0.l11_1.c13_1) {
            var tmp_7 = this.r13();
            // Inline function 'kotlinx.serialization.json.internal.AbstractJsonTreeDecoder.cast' call
            // Inline function 'kotlinx.serialization.json.internal.cast' call
            var serialName_1 = descriptor.wn();
            if (!(currentObject instanceof JsonArray)) {
              var tmp2_1 = 'Expected ' + getKClass(JsonArray).jc() + ', but had ' + getKClassFromExpression(currentObject).jc() + ' as the serialized body of ' + serialName_1;
              // Inline function 'kotlinx.serialization.json.internal.decodingExceptionOf' call
              var path_1 = this.xz();
              var tmp_8;
              if (this.r13().l11_1.q13_1) {
                var tmp$ret$23 = toString(currentObject);
                tmp_8 = toString(minify(tmp$ret$23));
              } else {
                tmp_8 = null;
              }
              var inputValue_1 = tmp_8;
              throw JsonDecodingException.e15(access$formatDecodingException$tJsonExceptionsKt(-1, tmp2_1, path_1, null, inputValue_1), tmp2_1, -1, path_1, inputValue_1, null);
            }
            tmp_3 = new JsonTreeListDecoder(tmp_7, currentObject);
          } else {
            throw InvalidKeyKindException(keyDescriptor);
          }
        }
        tmp = tmp_3;
      } else {
        var tmp_9 = this.r13();
        // Inline function 'kotlinx.serialization.json.internal.AbstractJsonTreeDecoder.cast' call
        // Inline function 'kotlinx.serialization.json.internal.cast' call
        var serialName_2 = descriptor.wn();
        if (!(currentObject instanceof JsonObject)) {
          var tmp2_2 = 'Expected ' + getKClass(JsonObject).jc() + ', but had ' + getKClassFromExpression(currentObject).jc() + ' as the serialized body of ' + serialName_2;
          // Inline function 'kotlinx.serialization.json.internal.decodingExceptionOf' call
          var path_2 = this.xz();
          var tmp_10;
          if (this.r13().l11_1.q13_1) {
            var tmp$ret$30 = toString(currentObject);
            tmp_10 = toString(minify(tmp$ret$30));
          } else {
            tmp_10 = null;
          }
          var inputValue_2 = tmp_10;
          throw JsonDecodingException.e15(access$formatDecodingException$tJsonExceptionsKt(-1, tmp2_2, path_2, null, inputValue_2), tmp2_2, -1, path_2, inputValue_2, null);
        }
        tmp = new JsonTreeDecoder(tmp_9, currentObject, this.f18_1);
      }
    }
    return tmp;
  }
  aq(descriptor) {
  }
  kp() {
    var tmp = this.i18();
    return !(tmp instanceof JsonNull);
  }
  k18(tag, enumDescriptor) {
    var tmp = this.r13();
    // Inline function 'kotlinx.serialization.json.internal.AbstractJsonTreeDecoder.getPrimitiveValue' call
    var tmp2 = this.j18(tag);
    // Inline function 'kotlinx.serialization.json.internal.AbstractJsonTreeDecoder.cast' call
    // Inline function 'kotlinx.serialization.json.internal.cast' call
    var serialName = enumDescriptor.wn();
    if (!(tmp2 instanceof JsonPrimitive)) {
      var tmp2_0 = 'Expected ' + getKClass(JsonPrimitive).jc() + ', but had ' + getKClassFromExpression(tmp2).jc() + ' as the serialized body of ' + serialName;
      // Inline function 'kotlinx.serialization.json.internal.decodingExceptionOf' call
      var path = this.h18(tag);
      var tmp_0;
      if (this.r13().l11_1.q13_1) {
        var tmp$ret$7 = toString(tmp2);
        tmp_0 = toString(minify(tmp$ret$7));
      } else {
        tmp_0 = null;
      }
      var inputValue = tmp_0;
      throw JsonDecodingException.e15(access$formatDecodingException$tJsonExceptionsKt(-1, tmp2_0, path, null, inputValue), tmp2_0, -1, path, inputValue, null);
    }
    return getJsonNameIndexOrThrow(enumDescriptor, tmp, tmp2.y13());
  }
  j10(tag, enumDescriptor) {
    return this.k18((!(tag == null) ? typeof tag === 'string' : false) ? tag : THROW_CCE(), enumDescriptor);
  }
  l18(tag) {
    return !(this.j18(tag) === JsonNull_getInstance());
  }
  zz(tag) {
    return this.l18((!(tag == null) ? typeof tag === 'string' : false) ? tag : THROW_CCE());
  }
  m18(tag) {
    var tmp$ret$0;
    $l$block: {
      // Inline function 'kotlinx.serialization.json.internal.AbstractJsonTreeDecoder.getPrimitiveValue' call
      // Inline function 'kotlinx.serialization.json.internal.AbstractJsonTreeDecoder.cast' call
      // Inline function 'kotlinx.serialization.json.internal.cast' call
      var value = this.j18(tag);
      if (!(value instanceof JsonPrimitive)) {
        var tmp2 = 'Expected ' + getKClass(JsonPrimitive).jc() + ', but had ' + getKClassFromExpression(value).jc() + ' as the serialized body of ' + 'boolean';
        // Inline function 'kotlinx.serialization.json.internal.decodingExceptionOf' call
        var path = this.h18(tag);
        var tmp;
        if (this.r13().l11_1.q13_1) {
          var tmp$ret$7 = toString(value);
          tmp = toString(minify(tmp$ret$7));
        } else {
          tmp = null;
        }
        var inputValue = tmp;
        throw JsonDecodingException.e15(access$formatDecodingException$tJsonExceptionsKt(-1, tmp2, path, null, inputValue), tmp2, -1, path, inputValue, null);
      }
      var literal = value;
      try {
        var tmp0_elvis_lhs = get_booleanOrNull(literal);
        var tmp_0;
        if (tmp0_elvis_lhs == null) {
          unparsedPrimitive(this, literal, 'boolean', tag);
        } else {
          tmp_0 = tmp0_elvis_lhs;
        }
        tmp$ret$0 = tmp_0;
        break $l$block;
      } catch ($p) {
        if ($p instanceof IllegalArgumentException) {
          var e = $p;
          unparsedPrimitive(this, literal, 'boolean', tag);
        } else {
          throw $p;
        }
      }
    }
    return tmp$ret$0;
  }
  a10(tag) {
    return this.m18((!(tag == null) ? typeof tag === 'string' : false) ? tag : THROW_CCE());
  }
  n18(tag) {
    var tmp$ret$0;
    $l$block: {
      // Inline function 'kotlinx.serialization.json.internal.AbstractJsonTreeDecoder.getPrimitiveValue' call
      // Inline function 'kotlinx.serialization.json.internal.AbstractJsonTreeDecoder.cast' call
      // Inline function 'kotlinx.serialization.json.internal.cast' call
      var value = this.j18(tag);
      if (!(value instanceof JsonPrimitive)) {
        var tmp2 = 'Expected ' + getKClass(JsonPrimitive).jc() + ', but had ' + getKClassFromExpression(value).jc() + ' as the serialized body of ' + 'byte';
        // Inline function 'kotlinx.serialization.json.internal.decodingExceptionOf' call
        var path = this.h18(tag);
        var tmp;
        if (this.r13().l11_1.q13_1) {
          var tmp$ret$7 = toString(value);
          tmp = toString(minify(tmp$ret$7));
        } else {
          tmp = null;
        }
        var inputValue = tmp;
        throw JsonDecodingException.e15(access$formatDecodingException$tJsonExceptionsKt(-1, tmp2, path, null, inputValue), tmp2, -1, path, inputValue, null);
      }
      var literal = value;
      try {
        var result = parseLongImpl(literal);
        var tmp_0;
        // Inline function 'kotlin.ranges.contains' call
        var this_0 = numberRangeToNumber(-128, 127);
        if (contains_0(isInterface(this_0, ClosedRange) ? this_0 : THROW_CCE(), result)) {
          tmp_0 = convertToByte(result);
        } else {
          tmp_0 = null;
        }
        var tmp0_elvis_lhs = tmp_0;
        var tmp_1;
        if (tmp0_elvis_lhs == null) {
          unparsedPrimitive(this, literal, 'byte', tag);
        } else {
          tmp_1 = tmp0_elvis_lhs;
        }
        tmp$ret$0 = tmp_1;
        break $l$block;
      } catch ($p) {
        if ($p instanceof IllegalArgumentException) {
          var e = $p;
          unparsedPrimitive(this, literal, 'byte', tag);
        } else {
          throw $p;
        }
      }
    }
    return tmp$ret$0;
  }
  b10(tag) {
    return this.n18((!(tag == null) ? typeof tag === 'string' : false) ? tag : THROW_CCE());
  }
  o18(tag) {
    var tmp$ret$0;
    $l$block: {
      // Inline function 'kotlinx.serialization.json.internal.AbstractJsonTreeDecoder.getPrimitiveValue' call
      // Inline function 'kotlinx.serialization.json.internal.AbstractJsonTreeDecoder.cast' call
      // Inline function 'kotlinx.serialization.json.internal.cast' call
      var value = this.j18(tag);
      if (!(value instanceof JsonPrimitive)) {
        var tmp2 = 'Expected ' + getKClass(JsonPrimitive).jc() + ', but had ' + getKClassFromExpression(value).jc() + ' as the serialized body of ' + 'short';
        // Inline function 'kotlinx.serialization.json.internal.decodingExceptionOf' call
        var path = this.h18(tag);
        var tmp;
        if (this.r13().l11_1.q13_1) {
          var tmp$ret$7 = toString(value);
          tmp = toString(minify(tmp$ret$7));
        } else {
          tmp = null;
        }
        var inputValue = tmp;
        throw JsonDecodingException.e15(access$formatDecodingException$tJsonExceptionsKt(-1, tmp2, path, null, inputValue), tmp2, -1, path, inputValue, null);
      }
      var literal = value;
      try {
        var result = parseLongImpl(literal);
        var tmp_0;
        // Inline function 'kotlin.ranges.contains' call
        var this_0 = numberRangeToNumber(-32768, 32767);
        if (contains_0(isInterface(this_0, ClosedRange) ? this_0 : THROW_CCE(), result)) {
          tmp_0 = convertToShort(result);
        } else {
          tmp_0 = null;
        }
        var tmp0_elvis_lhs = tmp_0;
        var tmp_1;
        if (tmp0_elvis_lhs == null) {
          unparsedPrimitive(this, literal, 'short', tag);
        } else {
          tmp_1 = tmp0_elvis_lhs;
        }
        tmp$ret$0 = tmp_1;
        break $l$block;
      } catch ($p) {
        if ($p instanceof IllegalArgumentException) {
          var e = $p;
          unparsedPrimitive(this, literal, 'short', tag);
        } else {
          throw $p;
        }
      }
    }
    return tmp$ret$0;
  }
  c10(tag) {
    return this.o18((!(tag == null) ? typeof tag === 'string' : false) ? tag : THROW_CCE());
  }
  p18(tag) {
    var tmp$ret$0;
    $l$block: {
      // Inline function 'kotlinx.serialization.json.internal.AbstractJsonTreeDecoder.getPrimitiveValue' call
      // Inline function 'kotlinx.serialization.json.internal.AbstractJsonTreeDecoder.cast' call
      // Inline function 'kotlinx.serialization.json.internal.cast' call
      var value = this.j18(tag);
      if (!(value instanceof JsonPrimitive)) {
        var tmp2 = 'Expected ' + getKClass(JsonPrimitive).jc() + ', but had ' + getKClassFromExpression(value).jc() + ' as the serialized body of ' + 'int';
        // Inline function 'kotlinx.serialization.json.internal.decodingExceptionOf' call
        var path = this.h18(tag);
        var tmp;
        if (this.r13().l11_1.q13_1) {
          var tmp$ret$7 = toString(value);
          tmp = toString(minify(tmp$ret$7));
        } else {
          tmp = null;
        }
        var inputValue = tmp;
        throw JsonDecodingException.e15(access$formatDecodingException$tJsonExceptionsKt(-1, tmp2, path, null, inputValue), tmp2, -1, path, inputValue, null);
      }
      var literal = value;
      try {
        var result = parseLongImpl(literal);
        var tmp_0;
        // Inline function 'kotlin.ranges.contains' call
        var this_0 = numberRangeToNumber(-2147483648, 2147483647);
        if (contains_0(isInterface(this_0, ClosedRange) ? this_0 : THROW_CCE(), result)) {
          tmp_0 = convertToInt(result);
        } else {
          tmp_0 = null;
        }
        var tmp0_elvis_lhs = tmp_0;
        var tmp_1;
        if (tmp0_elvis_lhs == null) {
          unparsedPrimitive(this, literal, 'int', tag);
        } else {
          tmp_1 = tmp0_elvis_lhs;
        }
        tmp$ret$0 = tmp_1;
        break $l$block;
      } catch ($p) {
        if ($p instanceof IllegalArgumentException) {
          var e = $p;
          unparsedPrimitive(this, literal, 'int', tag);
        } else {
          throw $p;
        }
      }
    }
    return tmp$ret$0;
  }
  d10(tag) {
    return this.p18((!(tag == null) ? typeof tag === 'string' : false) ? tag : THROW_CCE());
  }
  q18(tag) {
    var tmp$ret$0;
    $l$block: {
      // Inline function 'kotlinx.serialization.json.internal.AbstractJsonTreeDecoder.getPrimitiveValue' call
      // Inline function 'kotlinx.serialization.json.internal.AbstractJsonTreeDecoder.cast' call
      // Inline function 'kotlinx.serialization.json.internal.cast' call
      var value = this.j18(tag);
      if (!(value instanceof JsonPrimitive)) {
        var tmp2 = 'Expected ' + getKClass(JsonPrimitive).jc() + ', but had ' + getKClassFromExpression(value).jc() + ' as the serialized body of ' + 'long';
        // Inline function 'kotlinx.serialization.json.internal.decodingExceptionOf' call
        var path = this.h18(tag);
        var tmp;
        if (this.r13().l11_1.q13_1) {
          var tmp$ret$7 = toString(value);
          tmp = toString(minify(tmp$ret$7));
        } else {
          tmp = null;
        }
        var inputValue = tmp;
        throw JsonDecodingException.e15(access$formatDecodingException$tJsonExceptionsKt(-1, tmp2, path, null, inputValue), tmp2, -1, path, inputValue, null);
      }
      var literal = value;
      try {
        var tmp0_elvis_lhs = parseLongImpl(literal);
        var tmp_0;
        if (tmp0_elvis_lhs == null) {
          unparsedPrimitive(this, literal, 'long', tag);
        } else {
          tmp_0 = tmp0_elvis_lhs;
        }
        tmp$ret$0 = tmp_0;
        break $l$block;
      } catch ($p) {
        if ($p instanceof IllegalArgumentException) {
          var e = $p;
          unparsedPrimitive(this, literal, 'long', tag);
        } else {
          throw $p;
        }
      }
    }
    return tmp$ret$0;
  }
  e10(tag) {
    return this.q18((!(tag == null) ? typeof tag === 'string' : false) ? tag : THROW_CCE());
  }
  r18(tag) {
    var tmp$ret$0;
    $l$block: {
      // Inline function 'kotlinx.serialization.json.internal.AbstractJsonTreeDecoder.getPrimitiveValue' call
      // Inline function 'kotlinx.serialization.json.internal.AbstractJsonTreeDecoder.cast' call
      // Inline function 'kotlinx.serialization.json.internal.cast' call
      var value = this.j18(tag);
      if (!(value instanceof JsonPrimitive)) {
        var tmp2 = 'Expected ' + getKClass(JsonPrimitive).jc() + ', but had ' + getKClassFromExpression(value).jc() + ' as the serialized body of ' + 'float';
        // Inline function 'kotlinx.serialization.json.internal.decodingExceptionOf' call
        var path = this.h18(tag);
        var tmp;
        if (this.r13().l11_1.q13_1) {
          var tmp$ret$7 = toString(value);
          tmp = toString(minify(tmp$ret$7));
        } else {
          tmp = null;
        }
        var inputValue = tmp;
        throw JsonDecodingException.e15(access$formatDecodingException$tJsonExceptionsKt(-1, tmp2, path, null, inputValue), tmp2, -1, path, inputValue, null);
      }
      var literal = value;
      try {
        var tmp0_elvis_lhs = get_float(literal);
        var tmp_0;
        if (tmp0_elvis_lhs == null) {
          unparsedPrimitive(this, literal, 'float', tag);
        } else {
          tmp_0 = tmp0_elvis_lhs;
        }
        tmp$ret$0 = tmp_0;
        break $l$block;
      } catch ($p) {
        if ($p instanceof IllegalArgumentException) {
          var e = $p;
          unparsedPrimitive(this, literal, 'float', tag);
        } else {
          throw $p;
        }
      }
    }
    var result = tmp$ret$0;
    var specialFp = this.r13().l11_1.j13_1;
    if (specialFp || isFinite(result))
      return result;
    // Inline function 'kotlinx.serialization.json.internal.InvalidFloatingPointDecoded' call
    var tmp2_0 = access$nonFiniteFpMessage$tJsonExceptionsKt(result, tag);
    // Inline function 'kotlinx.serialization.json.internal.decodingExceptionOf' call
    var hint = "It is possible to deserialize them using 'JsonBuilder.allowSpecialFloatingPointValues = true'";
    var tmp_1;
    if (this.r13().l11_1.q13_1) {
      var tmp$ret$13 = toString(this.i18());
      tmp_1 = toString(minify(tmp$ret$13));
    } else {
      tmp_1 = null;
    }
    var inputValue_0 = tmp_1;
    throw JsonDecodingException.e15(access$formatDecodingException$tJsonExceptionsKt(-1, tmp2_0, null, hint, inputValue_0), tmp2_0, -1, null, inputValue_0, hint);
  }
  f10(tag) {
    return this.r18((!(tag == null) ? typeof tag === 'string' : false) ? tag : THROW_CCE());
  }
  s18(tag) {
    var tmp$ret$0;
    $l$block: {
      // Inline function 'kotlinx.serialization.json.internal.AbstractJsonTreeDecoder.getPrimitiveValue' call
      // Inline function 'kotlinx.serialization.json.internal.AbstractJsonTreeDecoder.cast' call
      // Inline function 'kotlinx.serialization.json.internal.cast' call
      var value = this.j18(tag);
      if (!(value instanceof JsonPrimitive)) {
        var tmp2 = 'Expected ' + getKClass(JsonPrimitive).jc() + ', but had ' + getKClassFromExpression(value).jc() + ' as the serialized body of ' + 'double';
        // Inline function 'kotlinx.serialization.json.internal.decodingExceptionOf' call
        var path = this.h18(tag);
        var tmp;
        if (this.r13().l11_1.q13_1) {
          var tmp$ret$7 = toString(value);
          tmp = toString(minify(tmp$ret$7));
        } else {
          tmp = null;
        }
        var inputValue = tmp;
        throw JsonDecodingException.e15(access$formatDecodingException$tJsonExceptionsKt(-1, tmp2, path, null, inputValue), tmp2, -1, path, inputValue, null);
      }
      var literal = value;
      try {
        var tmp0_elvis_lhs = get_double(literal);
        var tmp_0;
        if (tmp0_elvis_lhs == null) {
          unparsedPrimitive(this, literal, 'double', tag);
        } else {
          tmp_0 = tmp0_elvis_lhs;
        }
        tmp$ret$0 = tmp_0;
        break $l$block;
      } catch ($p) {
        if ($p instanceof IllegalArgumentException) {
          var e = $p;
          unparsedPrimitive(this, literal, 'double', tag);
        } else {
          throw $p;
        }
      }
    }
    var result = tmp$ret$0;
    var specialFp = this.r13().l11_1.j13_1;
    if (specialFp || isFinite_0(result))
      return result;
    // Inline function 'kotlinx.serialization.json.internal.InvalidFloatingPointDecoded' call
    var tmp2_0 = access$nonFiniteFpMessage$tJsonExceptionsKt(result, tag);
    // Inline function 'kotlinx.serialization.json.internal.decodingExceptionOf' call
    var hint = "It is possible to deserialize them using 'JsonBuilder.allowSpecialFloatingPointValues = true'";
    var tmp_1;
    if (this.r13().l11_1.q13_1) {
      var tmp$ret$13 = toString(this.i18());
      tmp_1 = toString(minify(tmp$ret$13));
    } else {
      tmp_1 = null;
    }
    var inputValue_0 = tmp_1;
    throw JsonDecodingException.e15(access$formatDecodingException$tJsonExceptionsKt(-1, tmp2_0, null, hint, inputValue_0), tmp2_0, -1, null, inputValue_0, hint);
  }
  g10(tag) {
    return this.s18((!(tag == null) ? typeof tag === 'string' : false) ? tag : THROW_CCE());
  }
  t18(tag) {
    var tmp$ret$0;
    $l$block: {
      // Inline function 'kotlinx.serialization.json.internal.AbstractJsonTreeDecoder.getPrimitiveValue' call
      // Inline function 'kotlinx.serialization.json.internal.AbstractJsonTreeDecoder.cast' call
      // Inline function 'kotlinx.serialization.json.internal.cast' call
      var value = this.j18(tag);
      if (!(value instanceof JsonPrimitive)) {
        var tmp2 = 'Expected ' + getKClass(JsonPrimitive).jc() + ', but had ' + getKClassFromExpression(value).jc() + ' as the serialized body of ' + 'char';
        // Inline function 'kotlinx.serialization.json.internal.decodingExceptionOf' call
        var path = this.h18(tag);
        var tmp;
        if (this.r13().l11_1.q13_1) {
          var tmp$ret$7 = toString(value);
          tmp = toString(minify(tmp$ret$7));
        } else {
          tmp = null;
        }
        var inputValue = tmp;
        throw JsonDecodingException.e15(access$formatDecodingException$tJsonExceptionsKt(-1, tmp2, path, null, inputValue), tmp2, -1, path, inputValue, null);
      }
      var literal = value;
      try {
        var tmp0_elvis_lhs = new Char(single(literal.y13()));
        var tmp_0;
        if (tmp0_elvis_lhs == null) {
          unparsedPrimitive(this, literal, 'char', tag);
        } else {
          tmp_0 = tmp0_elvis_lhs;
        }
        tmp$ret$0 = tmp_0.s1_1;
        break $l$block;
      } catch ($p) {
        if ($p instanceof IllegalArgumentException) {
          var e = $p;
          unparsedPrimitive(this, literal, 'char', tag);
        } else {
          throw $p;
        }
      }
    }
    return tmp$ret$0;
  }
  h10(tag) {
    return this.t18((!(tag == null) ? typeof tag === 'string' : false) ? tag : THROW_CCE());
  }
  u18(tag) {
    // Inline function 'kotlinx.serialization.json.internal.AbstractJsonTreeDecoder.cast' call
    // Inline function 'kotlinx.serialization.json.internal.cast' call
    var value = this.j18(tag);
    if (!(value instanceof JsonPrimitive)) {
      var tmp2 = 'Expected ' + getKClass(JsonPrimitive).jc() + ', but had ' + getKClassFromExpression(value).jc() + ' as the serialized body of ' + 'string';
      // Inline function 'kotlinx.serialization.json.internal.decodingExceptionOf' call
      var path = this.h18(tag);
      var tmp;
      if (this.r13().l11_1.q13_1) {
        var tmp$ret$6 = toString(value);
        tmp = toString(minify(tmp$ret$6));
      } else {
        tmp = null;
      }
      var inputValue = tmp;
      throw JsonDecodingException.e15(access$formatDecodingException$tJsonExceptionsKt(-1, tmp2, path, null, inputValue), tmp2, -1, path, inputValue, null);
    }
    var value_0 = value;
    if (!(value_0 instanceof JsonLiteral)) {
      var tmp2_0 = "Expected string value for a non-null key '" + tag + "', got null literal instead";
      var tmp4 = this.h18(tag);
      // Inline function 'kotlinx.serialization.json.internal.decodingExceptionOf' call
      var hint = "Use 'coerceInputValues = true' in 'Json {}' builder to coerce nulls if property has a default value.";
      var tmp_0;
      if (this.r13().l11_1.q13_1) {
        var tmp$ret$10 = toString(this.i18());
        tmp_0 = toString(minify(tmp$ret$10));
      } else {
        tmp_0 = null;
      }
      var inputValue_0 = tmp_0;
      throw JsonDecodingException.e15(access$formatDecodingException$tJsonExceptionsKt(-1, tmp2_0, tmp4, hint, inputValue_0), tmp2_0, -1, tmp4, inputValue_0, hint);
    }
    if (!value_0.a14_1 && !this.r13().l11_1.b13_1) {
      var tmp2_1 = "String literal for value of key '" + tag + "' should be quoted";
      var tmp4_0 = this.h18(tag);
      // Inline function 'kotlinx.serialization.json.internal.decodingExceptionOf' call
      var hint_0 = "Use 'isLenient = true' in 'Json {}' builder to accept non-compliant JSON.";
      var tmp_1;
      if (this.r13().l11_1.q13_1) {
        var tmp$ret$14 = toString(this.i18());
        tmp_1 = toString(minify(tmp$ret$14));
      } else {
        tmp_1 = null;
      }
      var inputValue_1 = tmp_1;
      throw JsonDecodingException.e15(access$formatDecodingException$tJsonExceptionsKt(-1, tmp2_1, tmp4_0, hint_0, inputValue_1), tmp2_1, -1, tmp4_0, inputValue_1, hint_0);
    }
    return value_0.c14_1;
  }
  i10(tag) {
    return this.u18((!(tag == null) ? typeof tag === 'string' : false) ? tag : THROW_CCE());
  }
  v18(tag, inlineDescriptor) {
    var tmp;
    if (get_isUnsignedNumber(inlineDescriptor)) {
      var tmp_0 = this.r13();
      // Inline function 'kotlinx.serialization.json.internal.AbstractJsonTreeDecoder.getPrimitiveValue' call
      var tmp2 = this.j18(tag);
      // Inline function 'kotlinx.serialization.json.internal.AbstractJsonTreeDecoder.cast' call
      // Inline function 'kotlinx.serialization.json.internal.cast' call
      var serialName = inlineDescriptor.wn();
      if (!(tmp2 instanceof JsonPrimitive)) {
        var tmp2_0 = 'Expected ' + getKClass(JsonPrimitive).jc() + ', but had ' + getKClassFromExpression(tmp2).jc() + ' as the serialized body of ' + serialName;
        // Inline function 'kotlinx.serialization.json.internal.decodingExceptionOf' call
        var path = this.h18(tag);
        var tmp_1;
        if (this.r13().l11_1.q13_1) {
          var tmp$ret$7 = toString(tmp2);
          tmp_1 = toString(minify(tmp$ret$7));
        } else {
          tmp_1 = null;
        }
        var inputValue = tmp_1;
        throw JsonDecodingException.e15(access$formatDecodingException$tJsonExceptionsKt(-1, tmp2_0, path, null, inputValue), tmp2_0, -1, path, inputValue, null);
      }
      var lexer = StringJsonLexer_0(tmp_0, tmp2.y13());
      tmp = new JsonDecoderForUnsignedTypes(lexer, this.r13());
    } else {
      tmp = super.k10(tag, inlineDescriptor);
    }
    return tmp;
  }
  k10(tag, inlineDescriptor) {
    return this.v18((!(tag == null) ? typeof tag === 'string' : false) ? tag : THROW_CCE(), inlineDescriptor);
  }
  wp(descriptor) {
    return !(this.vz() == null) ? super.wp(descriptor) : (new JsonPrimitiveDecoder(this.r13(), this.h2(), this.f18_1)).wp(descriptor);
  }
}
class JsonTreeDecoder extends AbstractJsonTreeDecoder {
  constructor(json, value, polymorphicDiscriminator, polyDescriptor) {
    polymorphicDiscriminator = polymorphicDiscriminator === VOID ? null : polymorphicDiscriminator;
    polyDescriptor = polyDescriptor === VOID ? null : polyDescriptor;
    super(json, value, polymorphicDiscriminator);
    this.c19_1 = value;
    this.d19_1 = polyDescriptor;
    this.e19_1 = 0;
    this.f19_1 = false;
  }
  h2() {
    return this.c19_1;
  }
  qq(descriptor) {
    $l$loop: while (this.e19_1 < descriptor.zn()) {
      var _unary__edvuaz = this.e19_1;
      this.e19_1 = _unary__edvuaz + 1 | 0;
      var name = this.qz(descriptor, _unary__edvuaz);
      var index = this.e19_1 - 1 | 0;
      this.f19_1 = false;
      var tmp;
      // Inline function 'kotlin.collections.contains' call
      // Inline function 'kotlin.collections.containsKey' call
      var this_0 = this.h2();
      if ((isInterface(this_0, KtMap) ? this_0 : THROW_CCE()).i2(name)) {
        tmp = true;
      } else {
        tmp = setForceNull(this, descriptor, index);
      }
      if (tmp) {
        if (!this.g18_1.g13_1)
          return index;
        var tmp0 = this.r13();
        var tmp$ret$2;
        $l$block_2: {
          // Inline function 'kotlinx.serialization.json.internal.tryCoerceValue' call
          var isOptional = descriptor.fo(index);
          var elementDescriptor = descriptor.eo(index);
          var tmp_0;
          if (isOptional && !elementDescriptor.qn()) {
            var tmp_1 = this.g19(name);
            tmp_0 = tmp_1 instanceof JsonNull;
          } else {
            tmp_0 = false;
          }
          if (tmp_0) {
            tmp$ret$2 = true;
            break $l$block_2;
          }
          if (equals(elementDescriptor.xn(), ENUM_getInstance())) {
            var tmp_2;
            if (elementDescriptor.qn()) {
              var tmp_3 = this.g19(name);
              tmp_2 = tmp_3 instanceof JsonNull;
            } else {
              tmp_2 = false;
            }
            if (tmp_2) {
              tmp$ret$2 = false;
              break $l$block_2;
            }
            var tmp_4 = this.g19(name);
            var tmp0_safe_receiver = tmp_4 instanceof JsonPrimitive ? tmp_4 : null;
            var tmp0_elvis_lhs = tmp0_safe_receiver == null ? null : get_contentOrNull(tmp0_safe_receiver);
            var tmp_5;
            if (tmp0_elvis_lhs == null) {
              tmp$ret$2 = false;
              break $l$block_2;
            } else {
              tmp_5 = tmp0_elvis_lhs;
            }
            var enumValue = tmp_5;
            var enumIndex = getJsonNameIndex(elementDescriptor, tmp0, enumValue);
            var coerceToNull = !tmp0.l11_1.e13_1 && elementDescriptor.qn();
            if (enumIndex === -3 && (isOptional || coerceToNull)) {
              if (setForceNull(this, descriptor, index))
                return index;
              tmp$ret$2 = true;
              break $l$block_2;
            }
          }
          tmp$ret$2 = false;
        }
        if (tmp$ret$2)
          continue $l$loop;
        return index;
      }
    }
    return -1;
  }
  kp() {
    return !this.f19_1 && super.kp();
  }
  rz(descriptor, index) {
    var strategy = namingStrategy(descriptor, this.r13());
    var baseName = descriptor.bo(index);
    if (strategy == null) {
      if (!this.g18_1.k13_1)
        return baseName;
      if (this.h2().l2().e2(baseName))
        return baseName;
    }
    var deserializationNamesMap_0 = deserializationNamesMap(this.r13(), descriptor);
    // Inline function 'kotlin.collections.find' call
    var tmp0 = this.h2().l2();
    var tmp$ret$1;
    $l$block: {
      // Inline function 'kotlin.collections.firstOrNull' call
      var _iterator__ex2g4s = tmp0.w();
      while (_iterator__ex2g4s.x()) {
        var element = _iterator__ex2g4s.y();
        if (deserializationNamesMap_0.k2(element) === index) {
          tmp$ret$1 = element;
          break $l$block;
        }
      }
      tmp$ret$1 = null;
    }
    var tmp0_safe_receiver = tmp$ret$1;
    if (tmp0_safe_receiver == null)
      null;
    else {
      // Inline function 'kotlin.let' call
      return tmp0_safe_receiver;
    }
    var fallbackName = strategy == null ? null : strategy.h16(descriptor, index, baseName);
    return fallbackName == null ? baseName : fallbackName;
  }
  j18(tag) {
    return getValue(this.h2(), tag);
  }
  g19(tag) {
    return this.h2().x13(tag);
  }
  zp(descriptor) {
    if (descriptor === this.d19_1) {
      var tmp = this.r13();
      var tmp2 = this.i18();
      // Inline function 'kotlinx.serialization.json.internal.AbstractJsonTreeDecoder.cast' call
      // Inline function 'kotlinx.serialization.json.internal.cast' call
      var serialName = this.d19_1.wn();
      if (!(tmp2 instanceof JsonObject)) {
        var tmp2_0 = 'Expected ' + getKClass(JsonObject).jc() + ', but had ' + getKClassFromExpression(tmp2).jc() + ' as the serialized body of ' + serialName;
        // Inline function 'kotlinx.serialization.json.internal.decodingExceptionOf' call
        var path = this.xz();
        var tmp_0;
        if (this.r13().l11_1.q13_1) {
          var tmp$ret$6 = toString(tmp2);
          tmp_0 = toString(minify(tmp$ret$6));
        } else {
          tmp_0 = null;
        }
        var inputValue = tmp_0;
        throw JsonDecodingException.e15(access$formatDecodingException$tJsonExceptionsKt(-1, tmp2_0, path, null, inputValue), tmp2_0, -1, path, inputValue, null);
      }
      return new JsonTreeDecoder(tmp, tmp2, this.f18_1, this.d19_1);
    }
    return super.zp(descriptor);
  }
  aq(descriptor) {
    var tmp;
    if (ignoreUnknownKeys(descriptor, this.r13())) {
      tmp = true;
    } else {
      var tmp_0 = descriptor.xn();
      tmp = tmp_0 instanceof PolymorphicKind;
    }
    if (tmp)
      return Unit_instance;
    var strategy = namingStrategy(descriptor, this.r13());
    var tmp_1;
    if (strategy == null && !this.g18_1.k13_1) {
      tmp_1 = jsonCachedSerialNames(descriptor);
    } else if (!(strategy == null)) {
      tmp_1 = deserializationNamesMap(this.r13(), descriptor).l2();
    } else {
      var tmp_2 = jsonCachedSerialNames(descriptor);
      var tmp0_safe_receiver = get_schemaCache(this.r13()).h17(descriptor, get_JsonDeserializationNamesKey());
      // Inline function 'kotlin.collections.orEmpty' call
      var tmp0_elvis_lhs = tmp0_safe_receiver == null ? null : tmp0_safe_receiver.l2();
      var tmp$ret$0 = tmp0_elvis_lhs == null ? emptySet() : tmp0_elvis_lhs;
      tmp_1 = plus_0(tmp_2, tmp$ret$0);
    }
    var names = tmp_1;
    var _iterator__ex2g4s = this.h2().l2().w();
    while (_iterator__ex2g4s.x()) {
      var key = _iterator__ex2g4s.y();
      if (!names.e2(key) && !(key === this.f18_1)) {
        var tmp2 = "Encountered an unknown key '" + key + "'";
        var tmp4 = this.xz();
        // Inline function 'kotlinx.serialization.json.internal.decodingExceptionOf' call
        var hint = "Use 'ignoreUnknownKeys = true' in 'Json {}' builder or '@JsonIgnoreUnknownKeys' annotation to ignore unknown keys.";
        var tmp_3;
        if (this.r13().l11_1.q13_1) {
          var tmp$ret$4 = this.h2().toString();
          tmp_3 = toString(minify(tmp$ret$4));
        } else {
          tmp_3 = null;
        }
        var inputValue = tmp_3;
        throw JsonDecodingException.e15(access$formatDecodingException$tJsonExceptionsKt(-1, tmp2, tmp4, hint, inputValue), tmp2, -1, tmp4, inputValue, hint);
      }
    }
  }
}
class JsonTreeListDecoder extends AbstractJsonTreeDecoder {
  constructor(json, value) {
    super(json, value);
    this.n19_1 = value;
    this.o19_1 = this.n19_1.b1();
    this.p19_1 = -1;
  }
  h2() {
    return this.n19_1;
  }
  rz(descriptor, index) {
    return index.toString();
  }
  j18(tag) {
    return this.n19_1.z(toInt(tag));
  }
  qq(descriptor) {
    while (this.p19_1 < (this.o19_1 - 1 | 0)) {
      this.p19_1 = this.p19_1 + 1 | 0;
      return this.p19_1;
    }
    return -1;
  }
}
class JsonPrimitiveDecoder extends AbstractJsonTreeDecoder {
  constructor(json, value, polymorphicDiscriminator) {
    polymorphicDiscriminator = polymorphicDiscriminator === VOID ? null : polymorphicDiscriminator;
    super(json, value, polymorphicDiscriminator);
    this.w19_1 = value;
    this.l10('primitive');
  }
  h2() {
    return this.w19_1;
  }
  qq(descriptor) {
    return 0;
  }
  j18(tag) {
    // Inline function 'kotlin.require' call
    if (!(tag === 'primitive')) {
      var message = "This input can only handle primitives with 'primitive' tag";
      throw IllegalArgumentException.r(toString(message));
    }
    return this.w19_1;
  }
}
class JsonTreeMapDecoder extends JsonTreeDecoder {
  constructor(json, value) {
    super(json, value);
    this.h1a_1 = value;
    this.i1a_1 = toList(this.h1a_1.l2());
    this.j1a_1 = imul(this.i1a_1.b1(), 2);
    this.k1a_1 = -1;
  }
  h2() {
    return this.h1a_1;
  }
  rz(descriptor, index) {
    var i = index / 2 | 0;
    return this.i1a_1.z(i);
  }
  qq(descriptor) {
    while (this.k1a_1 < (this.j1a_1 - 1 | 0)) {
      this.k1a_1 = this.k1a_1 + 1 | 0;
      return this.k1a_1;
    }
    return -1;
  }
  j18(tag) {
    return (this.k1a_1 % 2 | 0) === 0 ? JsonPrimitive_1(tag) : getValue(this.h1a_1, tag);
  }
  aq(descriptor) {
  }
}
class WriteMode extends Enum {
  constructor(name, ordinal, begin, end) {
    super(name, ordinal);
    this.u17_1 = begin;
    this.v17_1 = end;
  }
}
class AbstractJsonLexer {
  constructor(configuration) {
    this.z11_1 = configuration;
    this.a12_1 = 0;
    this.b12_1 = new JsonPath(this.z11_1);
    this.c12_1 = null;
    this.d12_1 = StringBuilder.t();
  }
  o1a() {
  }
  k17() {
    var current = this.p1a();
    var source = this.m1a();
    if (current >= charSequenceLength(source) || current === -1)
      return false;
    if (charSequenceGet(source, current) === _Char___init__impl__6a9atx(44)) {
      this.a12_1 = this.a12_1 + 1 | 0;
      return true;
    }
    return false;
  }
  q1a(c) {
    return c === _Char___init__impl__6a9atx(125) || c === _Char___init__impl__6a9atx(93) || (c === _Char___init__impl__6a9atx(58) || c === _Char___init__impl__6a9atx(44)) ? false : true;
  }
  e12() {
    var nextToken = this.e17();
    if (!(nextToken === 10)) {
      this.d16('Expected EOF after parsing, but had ' + toString_1(charSequenceGet(this.m1a(), this.a12_1 - 1 | 0)) + ' instead');
    }
  }
  y16(expected) {
    var token = this.e17();
    if (!(token === expected)) {
      // Inline function 'kotlinx.serialization.json.internal.AbstractJsonLexer.fail' call
      var expected_0 = tokenDescription(expected);
      var position = true && this.a12_1 > 0 ? this.a12_1 - 1 | 0 : this.a12_1;
      var s = this.a12_1 === charSequenceLength(this.m1a()) || position < 0 ? 'EOF' : toString_1(charSequenceGet(this.m1a(), position));
      var tmp$ret$1 = 'Expected ' + expected_0 + ", but had '" + s + "' instead";
      this.d16(tmp$ret$1, position);
    }
    return token;
  }
  r1a(expected) {
    if (this.a12_1 > 0 && expected === _Char___init__impl__6a9atx(34)) {
      var tmp$ret$0;
      $l$block: {
        // Inline function 'kotlinx.serialization.json.internal.AbstractJsonLexer.withPositionRollback' call
        var snapshot = this.a12_1;
        try {
          this.a12_1 = this.a12_1 - 1 | 0;
          tmp$ret$0 = this.c17();
          break $l$block;
        }finally {
          this.a12_1 = snapshot;
        }
      }
      var inputLiteral = tmp$ret$0;
      if (inputLiteral === 'null') {
        this.c16("Expected string literal but 'null' literal was found", this.a12_1 - 1 | 0, "Use 'coerceInputValues = true' in 'Json {}' builder to coerce nulls if property has a default value.");
      }
    }
    // Inline function 'kotlinx.serialization.json.internal.AbstractJsonLexer.fail' call
    var expectedToken = charToTokenClass(expected);
    var expected_0 = tokenDescription(expectedToken);
    var position = true && this.a12_1 > 0 ? this.a12_1 - 1 | 0 : this.a12_1;
    var s = this.a12_1 === charSequenceLength(this.m1a()) || position < 0 ? 'EOF' : toString_1(charSequenceGet(this.m1a(), position));
    var tmp$ret$3 = 'Expected ' + expected_0 + ", but had '" + s + "' instead";
    this.d16(tmp$ret$3, position);
  }
  z16() {
    var source = this.m1a();
    var cpos = this.a12_1;
    $l$loop_0: while (true) {
      cpos = this.n1a(cpos);
      if (cpos === -1)
        break $l$loop_0;
      var ch = charSequenceGet(source, cpos);
      if (ch === _Char___init__impl__6a9atx(32) || ch === _Char___init__impl__6a9atx(10) || ch === _Char___init__impl__6a9atx(13) || ch === _Char___init__impl__6a9atx(9)) {
        cpos = cpos + 1 | 0;
        continue $l$loop_0;
      }
      this.a12_1 = cpos;
      return charToTokenClass(ch);
    }
    this.a12_1 = cpos;
    return 10;
  }
  l17(doConsume) {
    var current = this.p1a();
    current = this.n1a(current);
    var len = charSequenceLength(this.m1a()) - current | 0;
    if (len < 4 || current === -1)
      return false;
    var inductionVariable = 0;
    if (inductionVariable <= 3)
      do {
        var i = inductionVariable;
        inductionVariable = inductionVariable + 1 | 0;
        if (!(charCodeAt('null', i) === charSequenceGet(this.m1a(), current + i | 0)))
          return false;
      }
       while (inductionVariable <= 3);
    if (len > 4 && charToTokenClass(charSequenceGet(this.m1a(), current + 4 | 0)) === 0)
      return false;
    if (doConsume) {
      this.a12_1 = current + 4 | 0;
    }
    return true;
  }
  w17(doConsume, $super) {
    doConsume = doConsume === VOID ? true : doConsume;
    return $super === VOID ? this.l17(doConsume) : $super.l17.call(this, doConsume);
  }
  m17(isLenient) {
    var token = this.z16();
    var tmp;
    if (isLenient) {
      if (!(token === 1) && !(token === 0))
        return null;
      tmp = this.c17();
    } else {
      if (!(token === 1))
        return null;
      tmp = this.b17();
    }
    var string = tmp;
    this.c12_1 = string;
    return string;
  }
  s1a() {
    this.c12_1 = null;
  }
  t1a(startPos, endPos) {
    // Inline function 'kotlin.text.substring' call
    var this_0 = this.m1a();
    return toString(charSequenceSubSequence(this_0, startPos, endPos));
  }
  b17() {
    if (!(this.c12_1 == null)) {
      return takePeeked(this);
    }
    return this.p17();
  }
  consumeString2(source, startPosition, current) {
    var currentPosition = current;
    var lastPosition = startPosition;
    var char = charSequenceGet(source, currentPosition);
    var usedAppend = false;
    while (!(char === _Char___init__impl__6a9atx(34))) {
      if (char === _Char___init__impl__6a9atx(92)) {
        usedAppend = true;
        currentPosition = this.n1a(appendEscape(this, lastPosition, currentPosition));
        if (currentPosition === -1) {
          this.d16('Unexpected EOF', currentPosition);
        }
        lastPosition = currentPosition;
      } else {
        currentPosition = currentPosition + 1 | 0;
        if (currentPosition >= charSequenceLength(source)) {
          usedAppend = true;
          this.l1a(lastPosition, currentPosition);
          currentPosition = this.n1a(currentPosition);
          if (currentPosition === -1) {
            this.d16('Unexpected EOF', currentPosition);
          }
          lastPosition = currentPosition;
        }
      }
      char = charSequenceGet(source, currentPosition);
    }
    var tmp;
    if (!usedAppend) {
      tmp = this.t1a(lastPosition, currentPosition);
    } else {
      tmp = decodedString(this, lastPosition, currentPosition);
    }
    var string = tmp;
    this.a12_1 = currentPosition + 1 | 0;
    return string;
  }
  q17() {
    var result = this.c17();
    if (result === 'null' && wasUnquotedString(this)) {
      this.d16("Unexpected 'null' value instead of string literal");
    }
    return result;
  }
  c17() {
    if (!(this.c12_1 == null)) {
      return takePeeked(this);
    }
    var current = this.p1a();
    if (current >= charSequenceLength(this.m1a()) || current === -1) {
      this.d16('EOF', current);
    }
    var token = charToTokenClass(charSequenceGet(this.m1a(), current));
    if (token === 1) {
      return this.b17();
    }
    if (!(token === 0)) {
      this.d16('Expected beginning of the string, but got ' + toString_1(charSequenceGet(this.m1a(), current)));
    }
    var usedAppend = false;
    while (charToTokenClass(charSequenceGet(this.m1a(), current)) === 0) {
      current = current + 1 | 0;
      if (current >= charSequenceLength(this.m1a())) {
        usedAppend = true;
        this.l1a(this.a12_1, current);
        var eof = this.n1a(current);
        if (eof === -1) {
          this.a12_1 = current;
          return decodedString(this, 0, 0);
        } else {
          current = eof;
        }
      }
    }
    var tmp;
    if (!usedAppend) {
      tmp = this.t1a(this.a12_1, current);
    } else {
      tmp = decodedString(this, this.a12_1, current);
    }
    var result = tmp;
    this.a12_1 = current;
    return result;
  }
  l1a(fromIndex, toIndex) {
    this.d12_1.rd(this.m1a(), fromIndex, toIndex);
  }
  o17(allowLenientStrings) {
    // Inline function 'kotlin.collections.mutableListOf' call
    var tokenStack = ArrayList.n();
    var lastToken = this.z16();
    if (!(lastToken === 8) && !(lastToken === 6)) {
      this.c17();
      return Unit_instance;
    }
    $l$loop: while (true) {
      lastToken = this.z16();
      if (lastToken === 1) {
        if (allowLenientStrings)
          this.c17();
        else
          this.p17();
        continue $l$loop;
      }
      var tmp0_subject = lastToken;
      if (tmp0_subject === 8 || tmp0_subject === 6) {
        tokenStack.u(lastToken);
      } else if (tmp0_subject === 9) {
        if (!(last(tokenStack) === 8)) {
          this.d16('found ] instead of }');
        }
        removeLast(tokenStack);
      } else if (tmp0_subject === 7) {
        if (!(last(tokenStack) === 6)) {
          this.d16('found } instead of ]');
        }
        removeLast(tokenStack);
      } else if (tmp0_subject === 10) {
        this.d16('Unexpected end of input due to malformed JSON during ignoring unknown keys');
      }
      this.e17();
      if (tokenStack.b1() === 0)
        return Unit_instance;
    }
  }
  toString() {
    return "JsonReader(source='" + toString(this.m1a()) + "', currentPosition=" + this.a12_1 + ')';
  }
  n17(key) {
    var processed = this.t1a(0, this.a12_1);
    var lastIndexOf_0 = lastIndexOf(processed, key);
    this.c16("Encountered an unknown key '" + key + "'", lastIndexOf_0, "Use 'ignoreUnknownKeys = true' in 'Json {}' builder or '@JsonIgnoreUnknownKeys' annotation to ignore unknown keys.");
  }
  c16(message, position, hint) {
    throw decodingExceptionOf_0(this, message, position, this.b12_1.r16(), hint, this.m1a());
  }
  d16(message, position, hint, $super) {
    position = position === VOID ? this.a12_1 : position;
    hint = hint === VOID ? null : hint;
    return $super === VOID ? this.c16(message, position, hint) : $super.c16.call(this, message, position, hint);
  }
  y17() {
    var current = this.p1a();
    current = this.n1a(current);
    if (current >= charSequenceLength(this.m1a()) || current === -1) {
      this.d16('EOF');
    }
    var tmp;
    if (charSequenceGet(this.m1a(), current) === _Char___init__impl__6a9atx(34)) {
      current = current + 1 | 0;
      if (current === charSequenceLength(this.m1a())) {
        this.d16('EOF');
      }
      tmp = true;
    } else {
      tmp = false;
    }
    var hasQuotation = tmp;
    var accumulator = new Long(0, 0);
    var exponentAccumulator = new Long(0, 0);
    var isNegative = false;
    var isExponentPositive = false;
    var hasExponent = false;
    var start = current;
    $l$loop_4: while (!(current === charSequenceLength(this.m1a()))) {
      var ch = charSequenceGet(this.m1a(), current);
      if ((ch === _Char___init__impl__6a9atx(101) || ch === _Char___init__impl__6a9atx(69)) && !hasExponent) {
        if (current === start) {
          this.d16("Unexpected symbol '" + toString_1(ch) + "' in numeric literal", current);
        }
        isExponentPositive = true;
        hasExponent = true;
        current = current + 1 | 0;
        continue $l$loop_4;
      }
      if (ch === _Char___init__impl__6a9atx(45) && hasExponent) {
        if (current === start) {
          this.d16("Unexpected symbol '-' in numeric literal", current);
        }
        isExponentPositive = false;
        current = current + 1 | 0;
        continue $l$loop_4;
      }
      if (ch === _Char___init__impl__6a9atx(43) && hasExponent) {
        if (current === start) {
          this.d16("Unexpected symbol '+' in numeric literal", current);
        }
        isExponentPositive = true;
        current = current + 1 | 0;
        continue $l$loop_4;
      }
      if (ch === _Char___init__impl__6a9atx(45)) {
        if (!(current === start)) {
          this.d16("Unexpected symbol '-' in numeric literal", current);
        }
        isNegative = true;
        current = current + 1 | 0;
        continue $l$loop_4;
      }
      var token = charToTokenClass(ch);
      if (!(token === 0))
        break $l$loop_4;
      current = current + 1 | 0;
      var digit = Char__minus_impl_a2frrh(ch, _Char___init__impl__6a9atx(48));
      if (!(0 <= digit ? digit <= 9 : false)) {
        this.d16("Unexpected symbol '" + toString_1(ch) + "' in numeric literal", current - 1 | 0);
      }
      if (hasExponent) {
        // Inline function 'kotlin.Long.times' call
        var this_0 = exponentAccumulator;
        // Inline function 'kotlin.Long.plus' call
        var this_1 = multiply(this_0, fromInt(10));
        exponentAccumulator = add(this_1, fromInt(digit));
        continue $l$loop_4;
      }
      // Inline function 'kotlin.Long.times' call
      var this_2 = accumulator;
      // Inline function 'kotlin.Long.minus' call
      var this_3 = multiply(this_2, fromInt(10));
      accumulator = subtract(this_3, fromInt(digit));
      if (compare(accumulator, new Long(0, 0)) > 0) {
        this.d16('Numeric value overflow');
      }
    }
    var hasChars = !(current === start);
    if (start === current || (isNegative && start === (current - 1 | 0))) {
      this.d16('Expected numeric literal', current);
    }
    if (hasQuotation) {
      if (!hasChars) {
        this.d16('EOF');
      }
      if (!(charSequenceGet(this.m1a(), current) === _Char___init__impl__6a9atx(34))) {
        this.d16('Expected closing quotation mark', current);
      }
      current = current + 1 | 0;
    }
    this.a12_1 = current;
    if (hasExponent) {
      var doubleAccumulator = toNumber(accumulator) * consumeNumericLiteral$calculateExponent(exponentAccumulator, isExponentPositive);
      if (doubleAccumulator > toNumber(new Long(-1, 2147483647)) || doubleAccumulator < toNumber(new Long(0, -2147483648))) {
        this.d16('Numeric value overflow');
      }
      // Inline function 'kotlin.math.floor' call
      if (!(Math.floor(doubleAccumulator) === doubleAccumulator)) {
        this.d16("Can't convert " + doubleAccumulator + ' to Long');
      }
      accumulator = numberToLong(doubleAccumulator);
    }
    var tmp_0;
    if (isNegative) {
      tmp_0 = accumulator;
    } else if (!equalsLong(accumulator, new Long(0, -2147483648))) {
      tmp_0 = negate(accumulator);
    } else {
      this.d16('Numeric value overflow');
    }
    return tmp_0;
  }
  d14() {
    var result = this.y17();
    var next = this.e17();
    if (!(next === 10)) {
      // Inline function 'kotlinx.serialization.json.internal.AbstractJsonLexer.fail' call
      var expected = tokenDescription(10);
      var position = true && this.a12_1 > 0 ? this.a12_1 - 1 | 0 : this.a12_1;
      var s = this.a12_1 === charSequenceLength(this.m1a()) || position < 0 ? 'EOF' : toString_1(charSequenceGet(this.m1a(), position));
      var tmp$ret$1 = "Expected input to contain a single valid number, but got '" + s + "' after it";
      this.d16(tmp$ret$1, position);
    }
    return result;
  }
  x17() {
    var current = this.p1a();
    if (current === charSequenceLength(this.m1a())) {
      this.d16('EOF');
    }
    var tmp;
    if (charSequenceGet(this.m1a(), current) === _Char___init__impl__6a9atx(34)) {
      current = current + 1 | 0;
      tmp = true;
    } else {
      tmp = false;
    }
    var hasQuotation = tmp;
    var result = consumeBoolean2(this, current);
    if (hasQuotation) {
      if (this.a12_1 === charSequenceLength(this.m1a())) {
        this.d16('EOF');
      }
      if (!(charSequenceGet(this.m1a(), this.a12_1) === _Char___init__impl__6a9atx(34))) {
        this.d16('Expected closing quotation mark');
      }
      this.a12_1 = this.a12_1 + 1 | 0;
    }
    return result;
  }
}
class CharMappings {
  constructor() {
    CharMappings_instance = this;
    this.u1a_1 = charArray(117);
    this.v1a_1 = new Int8Array(126);
    initEscape(this);
    initCharToToken(this);
  }
}
class StringJsonLexer extends AbstractJsonLexer {
  constructor(source, configuration) {
    super(configuration);
    this.h1b_1 = source;
  }
  m1a() {
    return this.h1b_1;
  }
  n1a(position) {
    return position < this.m1a().length ? position : -1;
  }
  e17() {
    var source = this.m1a();
    var cpos = this.a12_1;
    $l$loop: while (!(cpos === -1) && cpos < source.length) {
      var _unary__edvuaz = cpos;
      cpos = _unary__edvuaz + 1 | 0;
      var c = charCodeAt(source, _unary__edvuaz);
      // Inline function 'kotlinx.serialization.json.internal.AbstractJsonLexer.isWs' call
      if (c === _Char___init__impl__6a9atx(32) || c === _Char___init__impl__6a9atx(10) || c === _Char___init__impl__6a9atx(13) || c === _Char___init__impl__6a9atx(9))
        continue $l$loop;
      this.a12_1 = cpos;
      return charToTokenClass(c);
    }
    this.a12_1 = source.length;
    return 10;
  }
  a17() {
    var current = this.a12_1;
    if (current === -1)
      return false;
    var source = this.m1a();
    $l$loop: while (current < source.length) {
      var c = charCodeAt(source, current);
      // Inline function 'kotlinx.serialization.json.internal.AbstractJsonLexer.isWs' call
      if (c === _Char___init__impl__6a9atx(32) || c === _Char___init__impl__6a9atx(10) || c === _Char___init__impl__6a9atx(13) || c === _Char___init__impl__6a9atx(9)) {
        current = current + 1 | 0;
        continue $l$loop;
      }
      this.a12_1 = current;
      return this.q1a(c);
    }
    this.a12_1 = current;
    return false;
  }
  p1a() {
    var current = this.a12_1;
    if (current === -1)
      return current;
    var source = this.m1a();
    $l$loop: while (current < source.length) {
      var c = charCodeAt(source, current);
      // Inline function 'kotlinx.serialization.json.internal.AbstractJsonLexer.isWs' call
      if (c === _Char___init__impl__6a9atx(32) || c === _Char___init__impl__6a9atx(10) || c === _Char___init__impl__6a9atx(13) || c === _Char___init__impl__6a9atx(9)) {
        current = current + 1 | 0;
      } else {
        break $l$loop;
      }
    }
    this.a12_1 = current;
    return current;
  }
  j17(expected) {
    if (this.a12_1 === -1) {
      this.r1a(expected);
    }
    var source = this.m1a();
    var cpos = this.a12_1;
    $l$loop: while (cpos < source.length) {
      var _unary__edvuaz = cpos;
      cpos = _unary__edvuaz + 1 | 0;
      var c = charCodeAt(source, _unary__edvuaz);
      // Inline function 'kotlinx.serialization.json.internal.AbstractJsonLexer.isWs' call
      if (c === _Char___init__impl__6a9atx(32) || c === _Char___init__impl__6a9atx(10) || c === _Char___init__impl__6a9atx(13) || c === _Char___init__impl__6a9atx(9))
        continue $l$loop;
      this.a12_1 = cpos;
      if (c === expected)
        return Unit_instance;
      this.r1a(expected);
    }
    this.a12_1 = -1;
    this.r1a(expected);
  }
  p17() {
    this.j17(_Char___init__impl__6a9atx(34));
    var current = this.a12_1;
    var closingQuote = indexOf_0(this.m1a(), _Char___init__impl__6a9atx(34), current);
    if (closingQuote === -1) {
      this.c17();
      // Inline function 'kotlinx.serialization.json.internal.AbstractJsonLexer.fail' call
      var expected = tokenDescription(1);
      var position = false && this.a12_1 > 0 ? this.a12_1 - 1 | 0 : this.a12_1;
      var s = this.a12_1 === charSequenceLength(this.m1a()) || position < 0 ? 'EOF' : toString_1(charSequenceGet(this.m1a(), position));
      var tmp$ret$1 = 'Expected ' + expected + ", but had '" + s + "' instead";
      this.d16(tmp$ret$1, position);
    }
    var inductionVariable = current;
    if (inductionVariable < closingQuote)
      do {
        var i = inductionVariable;
        inductionVariable = inductionVariable + 1 | 0;
        if (charCodeAt(this.m1a(), i) === _Char___init__impl__6a9atx(92)) {
          return this.consumeString2(this.m1a(), this.a12_1, i);
        }
      }
       while (inductionVariable < closingQuote);
    this.a12_1 = closingQuote + 1 | 0;
    return substring(this.m1a(), current, closingQuote);
  }
  r17(keyToMatch, isLenient) {
    var positionSnapshot = this.a12_1;
    try {
      if (!(this.e17() === 6))
        return null;
      var firstKey = this.m17(isLenient);
      if (!(firstKey === keyToMatch))
        return null;
      this.s1a();
      if (!(this.e17() === 5))
        return null;
      return this.m17(isLenient);
    }finally {
      this.a12_1 = positionSnapshot;
      this.s1a();
    }
  }
}
class StringJsonLexerWithComments extends StringJsonLexer {
  e17() {
    var source = this.m1a();
    var cpos = this.p1a();
    if (cpos >= source.length || cpos === -1)
      return 10;
    this.a12_1 = cpos + 1 | 0;
    return charToTokenClass(charCodeAt(source, cpos));
  }
  a17() {
    var current = this.p1a();
    if (current >= this.m1a().length || current === -1)
      return false;
    return this.q1a(charCodeAt(this.m1a(), current));
  }
  j17(expected) {
    var source = this.m1a();
    var current = this.p1a();
    if (current >= source.length || current === -1) {
      this.a12_1 = -1;
      this.r1a(expected);
    }
    var c = charCodeAt(source, current);
    this.a12_1 = current + 1 | 0;
    if (c === expected)
      return Unit_instance;
    else {
      this.r1a(expected);
    }
  }
  z16() {
    var source = this.m1a();
    var cpos = this.p1a();
    if (cpos >= source.length || cpos === -1)
      return 10;
    this.a12_1 = cpos;
    return charToTokenClass(charCodeAt(source, cpos));
  }
  p1a() {
    var current = this.a12_1;
    if (current === -1)
      return current;
    var source = this.m1a();
    $l$loop_1: while (current < source.length) {
      var c = charCodeAt(source, current);
      // Inline function 'kotlinx.serialization.json.internal.AbstractJsonLexer.isWs' call
      if (c === _Char___init__impl__6a9atx(32) || c === _Char___init__impl__6a9atx(10) || c === _Char___init__impl__6a9atx(13) || c === _Char___init__impl__6a9atx(9)) {
        current = current + 1 | 0;
        continue $l$loop_1;
      }
      if (c === _Char___init__impl__6a9atx(47) && (current + 1 | 0) < source.length) {
        var tmp0_subject = charCodeAt(source, current + 1 | 0);
        if (tmp0_subject === _Char___init__impl__6a9atx(47)) {
          current = indexOf_0(source, _Char___init__impl__6a9atx(10), current + 2 | 0);
          if (current === -1) {
            current = source.length;
          } else {
            current = current + 1 | 0;
          }
          continue $l$loop_1;
        } else if (tmp0_subject === _Char___init__impl__6a9atx(42)) {
          current = indexOf(source, '*/', current + 2 | 0);
          if (current === -1) {
            this.a12_1 = source.length;
            this.d16('Expected end of the block comment: "*/", but had EOF instead');
          } else {
            current = current + 2 | 0;
          }
          continue $l$loop_1;
        }
      }
      break $l$loop_1;
    }
    this.a12_1 = current;
    return current;
  }
}
//endregion
var Default_instance;
function Default_getInstance() {
  if (Default_instance === VOID)
    new Default();
  return Default_instance;
}
function Json_0(from, builderAction) {
  from = from === VOID ? Default_getInstance() : from;
  var builder = new JsonBuilder(from);
  builderAction(builder);
  var conf = builder.y12();
  return new JsonImpl(conf, builder.w12_1);
}
function validateConfiguration($this) {
  if (equals($this.oq(), EmptySerializersModule()))
    return Unit_instance;
  var collector = new JsonSerializersModuleValidator($this.l11_1);
  $this.oq().w10(collector);
}
var ClassDiscriminatorMode_NONE_instance;
var ClassDiscriminatorMode_ALL_JSON_OBJECTS_instance;
var ClassDiscriminatorMode_POLYMORPHIC_instance;
var ClassDiscriminatorMode_entriesInitialized;
function ClassDiscriminatorMode_initEntries() {
  if (ClassDiscriminatorMode_entriesInitialized)
    return Unit_instance;
  ClassDiscriminatorMode_entriesInitialized = true;
  ClassDiscriminatorMode_NONE_instance = new ClassDiscriminatorMode('NONE', 0);
  ClassDiscriminatorMode_ALL_JSON_OBJECTS_instance = new ClassDiscriminatorMode('ALL_JSON_OBJECTS', 1);
  ClassDiscriminatorMode_POLYMORPHIC_instance = new ClassDiscriminatorMode('POLYMORPHIC', 2);
}
function ClassDiscriminatorMode_NONE_getInstance() {
  ClassDiscriminatorMode_initEntries();
  return ClassDiscriminatorMode_NONE_instance;
}
function ClassDiscriminatorMode_POLYMORPHIC_getInstance() {
  ClassDiscriminatorMode_initEntries();
  return ClassDiscriminatorMode_POLYMORPHIC_instance;
}
var jsonUnquotedLiteralDescriptor;
var Companion_instance;
function Companion_getInstance_3() {
  return Companion_instance;
}
var Companion_instance_0;
function Companion_getInstance_4() {
  return Companion_instance_0;
}
var Companion_instance_1;
function Companion_getInstance_5() {
  return Companion_instance_1;
}
function JsonObject$toString$lambda(_destruct__k2r9zo) {
  // Inline function 'kotlin.collections.component1' call
  var k = _destruct__k2r9zo.g2();
  // Inline function 'kotlin.collections.component2' call
  var v = _destruct__k2r9zo.h2();
  // Inline function 'kotlin.text.buildString' call
  // Inline function 'kotlin.apply' call
  var this_0 = StringBuilder.t();
  printQuoted(this_0, k);
  this_0.t9(_Char___init__impl__6a9atx(58));
  this_0.r9(v);
  return this_0.toString();
}
function get_jsonObject(_this__u8e3s4) {
  _init_properties_JsonElement_kt__7cbdc2();
  var tmp0_elvis_lhs = _this__u8e3s4 instanceof JsonObject ? _this__u8e3s4 : null;
  var tmp;
  if (tmp0_elvis_lhs == null) {
    error(_this__u8e3s4, 'JsonObject');
  } else {
    tmp = tmp0_elvis_lhs;
  }
  return tmp;
}
var Companion_instance_2;
function Companion_getInstance_6() {
  return Companion_instance_2;
}
function get_jsonPrimitive(_this__u8e3s4) {
  _init_properties_JsonElement_kt__7cbdc2();
  var tmp0_elvis_lhs = _this__u8e3s4 instanceof JsonPrimitive ? _this__u8e3s4 : null;
  var tmp;
  if (tmp0_elvis_lhs == null) {
    error(_this__u8e3s4, 'JsonPrimitive');
  } else {
    tmp = tmp0_elvis_lhs;
  }
  return tmp;
}
function get_double(_this__u8e3s4) {
  _init_properties_JsonElement_kt__7cbdc2();
  return toDouble(_this__u8e3s4.y13());
}
function JsonPrimitive_0(value) {
  _init_properties_JsonElement_kt__7cbdc2();
  if (value == null)
    return JsonNull_getInstance();
  return new JsonLiteral(value, false);
}
function JsonPrimitive_1(value) {
  _init_properties_JsonElement_kt__7cbdc2();
  if (value == null)
    return JsonNull_getInstance();
  return new JsonLiteral(value, true);
}
var JsonNull_instance;
function JsonNull_getInstance() {
  if (JsonNull_instance === VOID)
    new JsonNull();
  return JsonNull_instance;
}
function get_contentOrNull(_this__u8e3s4) {
  _init_properties_JsonElement_kt__7cbdc2();
  var tmp;
  if (_this__u8e3s4 instanceof JsonNull) {
    tmp = null;
  } else {
    tmp = _this__u8e3s4.y13();
  }
  return tmp;
}
function error(_this__u8e3s4, element) {
  _init_properties_JsonElement_kt__7cbdc2();
  throw IllegalArgumentException.r('Element ' + toString(getKClassFromExpression(_this__u8e3s4)) + ' is not a ' + element);
}
function JsonPrimitive_2(value) {
  _init_properties_JsonElement_kt__7cbdc2();
  if (value == null)
    return JsonNull_getInstance();
  return new JsonLiteral(value, false);
}
function get_booleanOrNull(_this__u8e3s4) {
  _init_properties_JsonElement_kt__7cbdc2();
  return toBooleanStrictOrNull(_this__u8e3s4.y13());
}
function parseLongImpl(_this__u8e3s4) {
  _init_properties_JsonElement_kt__7cbdc2();
  return StringJsonLexer_0(Default_getInstance(), _this__u8e3s4.y13()).d14();
}
function get_float(_this__u8e3s4) {
  _init_properties_JsonElement_kt__7cbdc2();
  // Inline function 'kotlin.text.toFloat' call
  var this_0 = _this__u8e3s4.y13();
  // Inline function 'kotlin.js.unsafeCast' call
  // Inline function 'kotlin.js.asDynamic' call
  return toDouble(this_0);
}
var properties_initialized_JsonElement_kt_abxy8s;
function _init_properties_JsonElement_kt__7cbdc2() {
  if (!properties_initialized_JsonElement_kt_abxy8s) {
    properties_initialized_JsonElement_kt_abxy8s = true;
    jsonUnquotedLiteralDescriptor = InlinePrimitiveDescriptor('kotlinx.serialization.json.JsonUnquotedLiteral', serializer(StringCompanionObject_instance));
  }
}
function put(_this__u8e3s4, key, value) {
  return _this__u8e3s4.f14(key, JsonPrimitive_1(value));
}
function put_0(_this__u8e3s4, key, value) {
  return _this__u8e3s4.f14(key, JsonPrimitive_0(value));
}
function put_1(_this__u8e3s4, key, value) {
  return _this__u8e3s4.f14(key, JsonPrimitive_2(value));
}
function putJsonArray(_this__u8e3s4, key, builderAction) {
  // Inline function 'kotlinx.serialization.json.buildJsonArray' call
  var builder = new JsonArrayBuilder();
  builderAction(builder);
  var tmp$ret$0 = builder.y12();
  return _this__u8e3s4.f14(key, tmp$ret$0);
}
var JsonArrayDescriptor_instance;
function JsonArrayDescriptor_getInstance() {
  if (JsonArrayDescriptor_instance === VOID)
    new JsonArrayDescriptor();
  return JsonArrayDescriptor_instance;
}
var JsonArraySerializer_instance;
function JsonArraySerializer_getInstance() {
  if (JsonArraySerializer_instance === VOID)
    new JsonArraySerializer();
  return JsonArraySerializer_instance;
}
function JsonElementSerializer$descriptor$lambda($this$buildSerialDescriptor) {
  $this$buildSerialDescriptor.vo('JsonPrimitive', defer(JsonElementSerializer$descriptor$lambda$lambda));
  $this$buildSerialDescriptor.vo('JsonNull', defer(JsonElementSerializer$descriptor$lambda$lambda_0));
  $this$buildSerialDescriptor.vo('JsonLiteral', defer(JsonElementSerializer$descriptor$lambda$lambda_1));
  $this$buildSerialDescriptor.vo('JsonObject', defer(JsonElementSerializer$descriptor$lambda$lambda_2));
  $this$buildSerialDescriptor.vo('JsonArray', defer(JsonElementSerializer$descriptor$lambda$lambda_3));
  return Unit_instance;
}
function JsonElementSerializer$descriptor$lambda$lambda() {
  return JsonPrimitiveSerializer_getInstance().l14_1;
}
function JsonElementSerializer$descriptor$lambda$lambda_0() {
  return JsonNullSerializer_getInstance().m14_1;
}
function JsonElementSerializer$descriptor$lambda$lambda_1() {
  return JsonLiteralSerializer_getInstance().n14_1;
}
function JsonElementSerializer$descriptor$lambda$lambda_2() {
  return JsonObjectSerializer_getInstance().o14_1;
}
function JsonElementSerializer$descriptor$lambda$lambda_3() {
  return JsonArraySerializer_getInstance().k14_1;
}
var JsonElementSerializer_instance;
function JsonElementSerializer_getInstance() {
  if (JsonElementSerializer_instance === VOID)
    new JsonElementSerializer();
  return JsonElementSerializer_instance;
}
var JsonObjectDescriptor_instance;
function JsonObjectDescriptor_getInstance() {
  if (JsonObjectDescriptor_instance === VOID)
    new JsonObjectDescriptor();
  return JsonObjectDescriptor_instance;
}
var JsonObjectSerializer_instance;
function JsonObjectSerializer_getInstance() {
  if (JsonObjectSerializer_instance === VOID)
    new JsonObjectSerializer();
  return JsonObjectSerializer_instance;
}
var JsonPrimitiveSerializer_instance;
function JsonPrimitiveSerializer_getInstance() {
  if (JsonPrimitiveSerializer_instance === VOID)
    new JsonPrimitiveSerializer();
  return JsonPrimitiveSerializer_instance;
}
var JsonNullSerializer_instance;
function JsonNullSerializer_getInstance() {
  if (JsonNullSerializer_instance === VOID)
    new JsonNullSerializer();
  return JsonNullSerializer_instance;
}
function verify(decoder) {
  asJsonDecoder(decoder);
}
function defer(deferred) {
  return new defer$1(deferred);
}
var JsonLiteralSerializer_instance;
function JsonLiteralSerializer_getInstance() {
  if (JsonLiteralSerializer_instance === VOID)
    new JsonLiteralSerializer();
  return JsonLiteralSerializer_instance;
}
function asJsonDecoder(_this__u8e3s4) {
  var tmp0_elvis_lhs = isInterface(_this__u8e3s4, JsonDecoder) ? _this__u8e3s4 : null;
  var tmp;
  if (tmp0_elvis_lhs == null) {
    throw IllegalStateException.j3('This serializer can be used only with Json format.' + ('Expected Decoder to be JsonDecoder, got ' + toString(getKClassFromExpression(_this__u8e3s4))));
  } else {
    tmp = tmp0_elvis_lhs;
  }
  return tmp;
}
function _get_original__l7ku1m($this) {
  var tmp0 = $this.f15_1;
  var tmp = KProperty1;
  // Inline function 'kotlin.getValue' call
  getPropertyCallableRef('original', 1, tmp, defer$o$_get_original_$ref_3cje7k(), null);
  return tmp0.h2();
}
function defer$o$_get_original_$ref_3cje7k() {
  return constructCallableReference((p0) => _get_original__l7ku1m(p0), 1, 0, 7);
}
function readIfAbsent($this, descriptor, index) {
  $this.z15_1 = (!descriptor.fo(index) && descriptor.eo(index).qn());
  return $this.z15_1;
}
function JsonElementMarker$readIfAbsent$ref(p0) {
  return constructCallableReference((p0_0, p1) => {
    var tmp0 = p0;
    return readIfAbsent(tmp0, p0_0, p1);
  }, 2, 0, 8, 'readIfAbsent', [p0]);
}
function minify(_this__u8e3s4, offset) {
  offset = offset === VOID ? -1 : offset;
  if (charSequenceLength(_this__u8e3s4) < 200)
    return _this__u8e3s4;
  if (offset === -1) {
    var start = charSequenceLength(_this__u8e3s4) - 60 | 0;
    if (start <= 0)
      return _this__u8e3s4;
    // Inline function 'kotlin.text.substring' call
    var endIndex = charSequenceLength(_this__u8e3s4);
    return '.....' + toString(charSequenceSubSequence(_this__u8e3s4, start, endIndex));
  }
  var start_0 = offset - 30 | 0;
  var end = offset + 30 | 0;
  var prefix = start_0 <= 0 ? '' : '.....';
  var suffix = end >= charSequenceLength(_this__u8e3s4) ? '' : '.....';
  var tmp2 = coerceAtLeast(start_0, 0);
  // Inline function 'kotlin.text.substring' call
  var endIndex_0 = coerceAtMost(end, charSequenceLength(_this__u8e3s4));
  return prefix + toString(charSequenceSubSequence(_this__u8e3s4, tmp2, endIndex_0)) + suffix;
}
function access$formatDecodingException$tJsonExceptionsKt(offset, shortMessage, path, hint, input) {
  return formatDecodingException(offset, shortMessage, path, hint, input);
}
function decodingExceptionOf(shortMessage) {
  return JsonDecodingException.e15(formatDecodingException(-1, shortMessage, null, null, null), shortMessage, -1, null, null, null);
}
function invalidTrailingComma(_this__u8e3s4, entity) {
  entity = entity === VOID ? 'object' : entity;
  _this__u8e3s4.c16('Trailing comma before the end of JSON ' + entity, _this__u8e3s4.a12_1 - 1 | 0, "Trailing commas are non-complaint JSON and not allowed by default. Use 'allowTrailingComma = true' in 'Json {}' builder to support them.");
}
function throwInvalidFloatingPointDecoded(_this__u8e3s4, result) {
  _this__u8e3s4.d16(nonFiniteFpMessage(result, null), VOID, "It is possible to deserialize them using 'JsonBuilder.allowSpecialFloatingPointValues = true'");
}
function InvalidKeyKindException(keyDescriptor) {
  return JsonEncodingException.x15("Value of type '" + keyDescriptor.wn() + "' can't be used in JSON as a key in the map. " + ("It should have either primitive or enum kind, but its kind is '" + keyDescriptor.xn().toString() + "'"), keyDescriptor.wn(), "Use 'allowStructuredMapKeys = true' in 'Json {}' builder to convert such maps to [key1, value1, key2, value2,...] arrays.");
}
function access$nonFiniteFpMessage$tJsonExceptionsKt(value, key) {
  return nonFiniteFpMessage(value, key);
}
function formatEncodingException(shortMessage, hint) {
  var tmp;
  // Inline function 'kotlin.text.isNullOrBlank' call
  if (hint == null || isBlank(hint)) {
    tmp = '';
  } else {
    tmp = '\n' + hint;
  }
  return shortMessage + tmp;
}
function formatDecodingException(offset, shortMessage, path, hint, input) {
  // Inline function 'kotlin.text.buildString' call
  // Inline function 'kotlin.apply' call
  var this_0 = StringBuilder.t();
  if (offset >= 0) {
    this_0.s9('Unexpected JSON token at offset ' + offset + ': ');
  }
  this_0.s9(shortMessage);
  // Inline function 'kotlin.text.isNullOrBlank' call
  if (!(path == null || isBlank(path))) {
    this_0.s9(' at path: ');
    this_0.s9(path);
  }
  // Inline function 'kotlin.text.isNullOrBlank' call
  if (!(hint == null || isBlank(hint))) {
    this_0.s9('\n' + hint);
  }
  if (!(input == null)) {
    this_0.s9('\nJSON input: ');
    this_0.s9(input);
  }
  return this_0.toString();
}
function nonFiniteFpMessage(value, key) {
  return 'Unexpected special floating-point value ' + toString(value) + (!(key == null) ? ' with key ' + key + '. ' : '. ') + 'By default, ' + 'non-finite floating point values are prohibited because they do not conform JSON specification.';
}
function decodingExceptionOf_0(_this__u8e3s4, shortMessage, offset, path, hint, input) {
  // Inline function 'kotlinx.serialization.json.internal.ifDebugInput' call
  var tmp;
  if (_this__u8e3s4.z11_1.q13_1) {
    tmp = toString(minify(input, offset));
  } else {
    tmp = null;
  }
  var inputValue = tmp;
  return JsonDecodingException.e15(formatDecodingException(offset, shortMessage, path, hint, inputValue), shortMessage, offset, path, inputValue, hint);
}
function get_JsonDeserializationNamesKey() {
  _init_properties_JsonNamesMap_kt__cbbp0k();
  return JsonDeserializationNamesKey;
}
var JsonDeserializationNamesKey;
var JsonSerializationNamesKey;
function ignoreUnknownKeys(_this__u8e3s4, json) {
  _init_properties_JsonNamesMap_kt__cbbp0k();
  var tmp;
  if (json.l11_1.a13_1) {
    tmp = true;
  } else {
    var tmp0 = _this__u8e3s4.ao();
    var tmp$ret$0;
    $l$block_0: {
      // Inline function 'kotlin.collections.any' call
      var tmp_0;
      if (isInterface(tmp0, Collection)) {
        tmp_0 = tmp0.a1();
      } else {
        tmp_0 = false;
      }
      if (tmp_0) {
        tmp$ret$0 = false;
        break $l$block_0;
      }
      var _iterator__ex2g4s = tmp0.w();
      while (_iterator__ex2g4s.x()) {
        var element = _iterator__ex2g4s.y();
        if (element instanceof JsonIgnoreUnknownKeys) {
          tmp$ret$0 = true;
          break $l$block_0;
        }
      }
      tmp$ret$0 = false;
    }
    tmp = tmp$ret$0;
  }
  return tmp;
}
function getJsonNameIndex(_this__u8e3s4, json, name) {
  _init_properties_JsonNamesMap_kt__cbbp0k();
  if (decodeCaseInsensitive(json, _this__u8e3s4)) {
    // Inline function 'kotlin.text.lowercase' call
    // Inline function 'kotlin.js.asDynamic' call
    var tmp$ret$0 = name.toLowerCase();
    return getJsonNameIndexSlowPath(_this__u8e3s4, json, tmp$ret$0);
  }
  var strategy = namingStrategy(_this__u8e3s4, json);
  if (!(strategy == null))
    return getJsonNameIndexSlowPath(_this__u8e3s4, json, name);
  var index = _this__u8e3s4.co(name);
  if (!(index === -3))
    return index;
  if (!json.l11_1.k13_1)
    return index;
  return getJsonNameIndexSlowPath(_this__u8e3s4, json, name);
}
function getJsonNameIndexOrThrow(_this__u8e3s4, json, name, suffix) {
  suffix = suffix === VOID ? '' : suffix;
  _init_properties_JsonNamesMap_kt__cbbp0k();
  var index = getJsonNameIndex(_this__u8e3s4, json, name);
  if (index === -3)
    throw SerializationException.cn(_this__u8e3s4.wn() + " does not contain element with name '" + name + "'" + suffix);
  return index;
}
function namingStrategy(_this__u8e3s4, json) {
  _init_properties_JsonNamesMap_kt__cbbp0k();
  return equals(_this__u8e3s4.xn(), CLASS_getInstance()) ? json.l11_1.l13_1 : null;
}
function deserializationNamesMap(_this__u8e3s4, descriptor) {
  _init_properties_JsonNamesMap_kt__cbbp0k();
  var tmp = get_schemaCache(_this__u8e3s4);
  var tmp_0 = get_JsonDeserializationNamesKey();
  return tmp.f16(descriptor, tmp_0, deserializationNamesMap$lambda(descriptor, _this__u8e3s4));
}
function decodeCaseInsensitive(_this__u8e3s4, descriptor) {
  _init_properties_JsonNamesMap_kt__cbbp0k();
  return _this__u8e3s4.l11_1.m13_1 && equals(descriptor.xn(), ENUM_getInstance());
}
function getJsonNameIndexSlowPath(_this__u8e3s4, json, name) {
  _init_properties_JsonNamesMap_kt__cbbp0k();
  var tmp0_elvis_lhs = deserializationNamesMap(json, _this__u8e3s4).k2(name);
  return tmp0_elvis_lhs == null ? -3 : tmp0_elvis_lhs;
}
function buildDeserializationNamesMap(_this__u8e3s4, json) {
  _init_properties_JsonNamesMap_kt__cbbp0k();
  // Inline function 'kotlin.collections.mutableMapOf' call
  var builder = LinkedHashMap.ea();
  var useLowercaseEnums = decodeCaseInsensitive(json, _this__u8e3s4);
  var strategyForClasses = namingStrategy(_this__u8e3s4, json);
  var inductionVariable = 0;
  var last = _this__u8e3s4.zn();
  if (inductionVariable < last)
    do {
      var i = inductionVariable;
      inductionVariable = inductionVariable + 1 | 0;
      // Inline function 'kotlin.collections.filterIsInstance' call
      var tmp0 = _this__u8e3s4.do(i);
      // Inline function 'kotlin.collections.filterIsInstanceTo' call
      var destination = ArrayList.n();
      var _iterator__ex2g4s = tmp0.w();
      while (_iterator__ex2g4s.x()) {
        var element = _iterator__ex2g4s.y();
        if (element instanceof JsonNames) {
          destination.u(element);
        }
      }
      var tmp0_safe_receiver = singleOrNull(destination);
      var tmp1_safe_receiver = tmp0_safe_receiver == null ? null : tmp0_safe_receiver.g16_1;
      if (tmp1_safe_receiver == null)
        null;
      else {
        // Inline function 'kotlin.collections.forEach' call
        var inductionVariable_0 = 0;
        var last_0 = tmp1_safe_receiver.length;
        while (inductionVariable_0 < last_0) {
          var element_0 = tmp1_safe_receiver[inductionVariable_0];
          inductionVariable_0 = inductionVariable_0 + 1 | 0;
          var tmp;
          if (useLowercaseEnums) {
            // Inline function 'kotlin.text.lowercase' call
            // Inline function 'kotlin.js.asDynamic' call
            tmp = element_0.toLowerCase();
          } else {
            tmp = element_0;
          }
          buildDeserializationNamesMap$putOrThrow(builder, _this__u8e3s4, tmp, i);
        }
      }
      var tmp_0;
      if (useLowercaseEnums) {
        // Inline function 'kotlin.text.lowercase' call
        // Inline function 'kotlin.js.asDynamic' call
        tmp_0 = _this__u8e3s4.bo(i).toLowerCase();
      } else if (!(strategyForClasses == null)) {
        tmp_0 = strategyForClasses.h16(_this__u8e3s4, i, _this__u8e3s4.bo(i));
      } else {
        tmp_0 = null;
      }
      var nameToPut = tmp_0;
      if (nameToPut == null)
        null;
      else {
        // Inline function 'kotlin.let' call
        buildDeserializationNamesMap$putOrThrow(builder, _this__u8e3s4, nameToPut, i);
      }
    }
     while (inductionVariable < last);
  // Inline function 'kotlin.collections.ifEmpty' call
  var tmp_1;
  if (builder.a1()) {
    tmp_1 = emptyMap();
  } else {
    tmp_1 = builder;
  }
  return tmp_1;
}
function deserializationNamesMap$lambda($descriptor, $this_deserializationNamesMap) {
  return () => buildDeserializationNamesMap($descriptor, $this_deserializationNamesMap);
}
function buildDeserializationNamesMap$putOrThrow(_this__u8e3s4, $this_buildDeserializationNamesMap, name, index) {
  var entity = equals($this_buildDeserializationNamesMap.xn(), ENUM_getInstance()) ? 'enum value' : 'property';
  // Inline function 'kotlin.collections.contains' call
  // Inline function 'kotlin.collections.containsKey' call
  if ((isInterface(_this__u8e3s4, KtMap) ? _this__u8e3s4 : THROW_CCE()).i2(name)) {
    throw decodingExceptionOf("The suggested name '" + name + "' for " + entity + ' ' + $this_buildDeserializationNamesMap.bo(index) + ' is already one of the names for ' + entity + ' ' + ($this_buildDeserializationNamesMap.bo(getValue(_this__u8e3s4, name)) + ' in ' + toString($this_buildDeserializationNamesMap)));
  }
  // Inline function 'kotlin.collections.set' call
  _this__u8e3s4.o2(name, index);
}
var properties_initialized_JsonNamesMap_kt_ljpf42;
function _init_properties_JsonNamesMap_kt__cbbp0k() {
  if (!properties_initialized_JsonNamesMap_kt_ljpf42) {
    properties_initialized_JsonNamesMap_kt_ljpf42 = true;
    JsonDeserializationNamesKey = new Key();
    JsonSerializationNamesKey = new Key();
  }
}
var Tombstone_instance;
function Tombstone_getInstance() {
  return Tombstone_instance;
}
var RedactedKey_instance;
function RedactedKey_getInstance() {
  return RedactedKey_instance;
}
function resize($this) {
  var newSize = imul($this.l16_1, 2);
  $this.j16_1 = copyOf($this.j16_1, newSize);
  var tmp = 0;
  var tmp_0 = new Int32Array(newSize);
  while (tmp < newSize) {
    tmp_0[tmp] = -1;
    tmp = tmp + 1 | 0;
  }
  var newIndices = tmp_0;
  // Inline function 'kotlin.collections.copyInto' call
  var this_0 = $this.k16_1;
  var endIndex = this_0.length;
  // Inline function 'kotlin.js.unsafeCast' call
  // Inline function 'kotlin.js.asDynamic' call
  var tmp_1 = this_0;
  // Inline function 'kotlin.js.unsafeCast' call
  // Inline function 'kotlin.js.asDynamic' call
  arrayCopy(tmp_1, newIndices, 0, 0, endIndex);
  $this.k16_1 = newIndices;
}
function checkKind($this, descriptor, actualClass) {
  var kind = descriptor.xn();
  var tmp;
  if (kind instanceof PolymorphicKind) {
    tmp = true;
  } else {
    tmp = equals(kind, CONTEXTUAL_getInstance());
  }
  if (tmp) {
    throw IllegalArgumentException.r('Serializer for ' + actualClass.jc() + " can't be registered as a subclass for polymorphic serialization " + ('because its kind ' + kind.toString() + ' is not concrete. To work with multiple hierarchies, register it as a base class.'));
  }
  if ($this.s16_1)
    return Unit_instance;
  if (!$this.t16_1)
    return Unit_instance;
  var tmp_0;
  var tmp_1;
  if (equals(kind, LIST_getInstance()) || equals(kind, MAP_getInstance())) {
    tmp_1 = true;
  } else {
    tmp_1 = kind instanceof PrimitiveKind;
  }
  if (tmp_1) {
    tmp_0 = true;
  } else {
    tmp_0 = kind instanceof ENUM;
  }
  if (tmp_0) {
    throw IllegalArgumentException.r('Serializer for ' + actualClass.jc() + ' of kind ' + kind.toString() + ' cannot be serialized polymorphically with class discriminator.');
  }
}
function readObject($this) {
  // Inline function 'kotlinx.serialization.json.internal.JsonTreeReader.readObjectImpl' call
  var lastToken = $this.u16_1.y16(6);
  if ($this.u16_1.z16() === 4) {
    $this.u16_1.d16('Unexpected leading comma');
  }
  // Inline function 'kotlin.collections.linkedMapOf' call
  var result = LinkedHashMap.ea();
  $l$loop: while ($this.u16_1.a17()) {
    var key = $this.v16_1 ? $this.u16_1.c17() : $this.u16_1.b17();
    $this.u16_1.y16(5);
    var element = $this.d17();
    // Inline function 'kotlin.collections.set' call
    result.o2(key, element);
    lastToken = $this.u16_1.e17();
    var tmp0_subject = lastToken;
    if (tmp0_subject !== 4)
      if (tmp0_subject === 7)
        break $l$loop;
      else {
        $this.u16_1.d16('Expected end of the object or comma');
      }
  }
  if (lastToken === 6) {
    $this.u16_1.y16(7);
  } else if (lastToken === 4) {
    if (!$this.w16_1) {
      invalidTrailingComma($this.u16_1);
    }
    $this.u16_1.y16(7);
  }
  return new JsonObject(result);
}
function *readObject_0($this, $receiver, $completion) {
  // Inline function 'kotlinx.serialization.json.internal.JsonTreeReader.readObjectImpl' call
  var lastToken = $this.u16_1.y16(6);
  if ($this.u16_1.z16() === 4) {
    $this.u16_1.d16('Unexpected leading comma');
  }
  // Inline function 'kotlin.collections.linkedMapOf' call
  var result = LinkedHashMap.ea();
  $l$loop: while ($this.u16_1.a17()) {
    var key = $this.v16_1 ? $this.u16_1.c17() : $this.u16_1.b17();
    $this.u16_1.y16(5);
    var element = yield* $receiver.ik(Unit_instance, $completion);
    // Inline function 'kotlin.collections.set' call
    result.o2(key, element);
    lastToken = $this.u16_1.e17();
    var tmp0_subject = lastToken;
    if (tmp0_subject !== 4)
      if (tmp0_subject === 7)
        break $l$loop;
      else {
        $this.u16_1.d16('Expected end of the object or comma');
      }
  }
  if (lastToken === 6) {
    $this.u16_1.y16(7);
  } else if (lastToken === 4) {
    if (!$this.w16_1) {
      invalidTrailingComma($this.u16_1);
    }
    $this.u16_1.y16(7);
  }
  return new JsonObject(result);
}
function readArray($this) {
  var lastToken = $this.u16_1.e17();
  if ($this.u16_1.z16() === 4) {
    $this.u16_1.d16('Unexpected leading comma');
  }
  // Inline function 'kotlin.collections.arrayListOf' call
  var result = ArrayList.n();
  while ($this.u16_1.a17()) {
    var element = $this.d17();
    result.u(element);
    lastToken = $this.u16_1.e17();
    if (!(lastToken === 4)) {
      var tmp0 = $this.u16_1;
      // Inline function 'kotlinx.serialization.json.internal.AbstractJsonLexer.require' call
      var condition = lastToken === 9;
      var position = tmp0.a12_1;
      if (!condition) {
        var tmp$ret$2 = 'Expected end of the array or comma';
        tmp0.d16(tmp$ret$2, position);
      }
    }
  }
  if (lastToken === 8) {
    $this.u16_1.y16(9);
  } else if (lastToken === 4) {
    if (!$this.w16_1) {
      invalidTrailingComma($this.u16_1, 'array');
    }
    $this.u16_1.y16(9);
  }
  return new JsonArray(result);
}
function readValue($this, isString) {
  var tmp;
  if ($this.v16_1 || !isString) {
    tmp = $this.u16_1.c17();
  } else {
    tmp = $this.u16_1.b17();
  }
  var string = tmp;
  if (!isString && string === 'null')
    return JsonNull_getInstance();
  return new JsonLiteral(string, isString);
}
function readDeepRecursive($this) {
  return invoke(new DeepRecursiveFunction(JsonTreeReader$readDeepRecursive$slambda($this)), Unit_instance);
}
function JsonTreeReader$readDeepRecursive$slambda(this$0) {
  return constructCallableReference(function *($this$DeepRecursiveFunction, it, $completion) {
    var tmp0_subject = this$0.u16_1.z16();
    var tmp;
    if (tmp0_subject === 1) {
      tmp = readValue(this$0, true);
    } else if (tmp0_subject === 0) {
      tmp = readValue(this$0, false);
    } else if (tmp0_subject === 6) {
      tmp = yield* /*#__NOINLINE__*/readObject_0(this$0, $this$DeepRecursiveFunction, $completion);
    } else if (tmp0_subject === 8) {
      tmp = readArray(this$0);
    } else {
      this$0.u16_1.d16("Can't begin reading element, unexpected token");
    }
    return tmp;
  }, 2);
}
function classDiscriminator(_this__u8e3s4, json) {
  var _iterator__ex2g4s = _this__u8e3s4.ao().w();
  while (_iterator__ex2g4s.x()) {
    var annotation = _iterator__ex2g4s.y();
    if (annotation instanceof JsonClassDiscriminator)
      return annotation.f17_1;
  }
  return json.l11_1.i13_1;
}
function trySkip($this, $receiver, unknownKey) {
  if ($receiver == null)
    return false;
  if ($receiver.i17_1 === unknownKey) {
    $receiver.i17_1 = null;
    return true;
  }
  return false;
}
function skipLeftoverElements($this, descriptor) {
  while (!($this.qq(descriptor) === -1)) {
  }
}
function checkLeadingComma($this) {
  if ($this.t11_1.z16() === 4) {
    $this.t11_1.d16('Unexpected leading comma');
  }
}
function decodeMapIndex($this) {
  var hasComma = false;
  var decodingKey = !(($this.v11_1 % 2 | 0) === 0);
  if (decodingKey) {
    if (!($this.v11_1 === -1)) {
      hasComma = $this.t11_1.k17();
    }
  } else {
    $this.t11_1.j17(_Char___init__impl__6a9atx(58));
  }
  var tmp;
  if ($this.t11_1.a17()) {
    if (decodingKey) {
      if ($this.v11_1 === -1) {
        var tmp0 = $this.t11_1;
        // Inline function 'kotlinx.serialization.json.internal.AbstractJsonLexer.require' call
        var condition = !hasComma;
        var position = tmp0.a12_1;
        if (!condition) {
          var tmp$ret$1 = 'Unexpected leading comma';
          tmp0.d16(tmp$ret$1, position);
        }
      } else {
        var tmp0_0 = $this.t11_1;
        // Inline function 'kotlinx.serialization.json.internal.AbstractJsonLexer.require' call
        var condition_0 = hasComma;
        var position_0 = tmp0_0.a12_1;
        if (!condition_0) {
          var tmp$ret$3 = 'Expected comma after the key-value pair';
          tmp0_0.d16(tmp$ret$3, position_0);
        }
      }
    }
    $this.v11_1 = $this.v11_1 + 1 | 0;
    tmp = $this.v11_1;
  } else {
    if (hasComma && !$this.r11_1.l11_1.n13_1) {
      invalidTrailingComma($this.t11_1);
    }
    tmp = -1;
  }
  return tmp;
}
function coerceInputValue($this, descriptor, index) {
  var tmp0 = $this.r11_1;
  var tmp$ret$0;
  $l$block_2: {
    // Inline function 'kotlinx.serialization.json.internal.tryCoerceValue' call
    var isOptional = descriptor.fo(index);
    var elementDescriptor = descriptor.eo(index);
    var tmp;
    if (isOptional && !elementDescriptor.qn()) {
      tmp = $this.t11_1.l17(true);
    } else {
      tmp = false;
    }
    if (tmp) {
      tmp$ret$0 = true;
      break $l$block_2;
    }
    if (equals(elementDescriptor.xn(), ENUM_getInstance())) {
      var tmp_0;
      if (elementDescriptor.qn()) {
        tmp_0 = $this.t11_1.l17(false);
      } else {
        tmp_0 = false;
      }
      if (tmp_0) {
        tmp$ret$0 = false;
        break $l$block_2;
      }
      var tmp0_elvis_lhs = $this.t11_1.m17($this.x11_1.b13_1);
      var tmp_1;
      if (tmp0_elvis_lhs == null) {
        tmp$ret$0 = false;
        break $l$block_2;
      } else {
        tmp_1 = tmp0_elvis_lhs;
      }
      var enumValue = tmp_1;
      var enumIndex = getJsonNameIndex(elementDescriptor, tmp0, enumValue);
      var coerceToNull = !tmp0.l11_1.e13_1 && elementDescriptor.qn();
      if (enumIndex === -3 && (isOptional || coerceToNull)) {
        $this.t11_1.b17();
        tmp$ret$0 = true;
        break $l$block_2;
      }
    }
    tmp$ret$0 = false;
  }
  return tmp$ret$0;
}
function decodeObjectIndex($this, descriptor) {
  var hasComma = $this.t11_1.k17();
  while ($this.t11_1.a17()) {
    hasComma = false;
    var key = decodeStringKey($this);
    $this.t11_1.j17(_Char___init__impl__6a9atx(58));
    var index = getJsonNameIndex(descriptor, $this.r11_1, key);
    var tmp;
    if (!(index === -3)) {
      var tmp_0;
      if ($this.x11_1.g13_1 && coerceInputValue($this, descriptor, index)) {
        hasComma = $this.t11_1.k17();
        tmp_0 = false;
      } else {
        var tmp0_safe_receiver = $this.y11_1;
        if (tmp0_safe_receiver == null)
          null;
        else {
          tmp0_safe_receiver.a16(index);
        }
        return index;
      }
      tmp = tmp_0;
    } else {
      tmp = true;
    }
    var isUnknown = tmp;
    if (isUnknown) {
      hasComma = handleUnknown($this, descriptor, key);
    }
  }
  if (hasComma && !$this.r11_1.l11_1.n13_1) {
    invalidTrailingComma($this.t11_1);
  }
  var tmp1_safe_receiver = $this.y11_1;
  var tmp2_elvis_lhs = tmp1_safe_receiver == null ? null : tmp1_safe_receiver.b16();
  return tmp2_elvis_lhs == null ? -1 : tmp2_elvis_lhs;
}
function handleUnknown($this, descriptor, key) {
  if (ignoreUnknownKeys(descriptor, $this.r11_1) || trySkip($this, $this.w11_1, key)) {
    $this.t11_1.o17($this.x11_1.b13_1);
  } else {
    $this.t11_1.b12_1.q16();
    $this.t11_1.n17(key);
  }
  return $this.t11_1.k17();
}
function decodeListIndex($this) {
  var hasComma = $this.t11_1.k17();
  var tmp;
  if ($this.t11_1.a17()) {
    if (!($this.v11_1 === -1) && !hasComma) {
      $this.t11_1.d16('Expected end of the array or comma');
    }
    $this.v11_1 = $this.v11_1 + 1 | 0;
    tmp = $this.v11_1;
  } else {
    if (hasComma && !$this.r11_1.l11_1.n13_1) {
      invalidTrailingComma($this.t11_1, 'array');
    }
    tmp = -1;
  }
  return tmp;
}
function decodeStringKey($this) {
  var tmp;
  if ($this.x11_1.b13_1) {
    tmp = $this.t11_1.q17();
  } else {
    tmp = $this.t11_1.p17();
  }
  return tmp;
}
function get_unsignedNumberDescriptors() {
  _init_properties_StreamingJsonEncoder_kt__pn1bsi();
  return unsignedNumberDescriptors;
}
var unsignedNumberDescriptors;
function get_isUnsignedNumber(_this__u8e3s4) {
  _init_properties_StreamingJsonEncoder_kt__pn1bsi();
  return _this__u8e3s4.yn() && get_unsignedNumberDescriptors().e2(_this__u8e3s4);
}
var properties_initialized_StreamingJsonEncoder_kt_6ifwwk;
function _init_properties_StreamingJsonEncoder_kt__pn1bsi() {
  if (!properties_initialized_StreamingJsonEncoder_kt_6ifwwk) {
    properties_initialized_StreamingJsonEncoder_kt_6ifwwk = true;
    unsignedNumberDescriptors = setOf([serializer_0(Companion_getInstance()).om(), serializer_1(Companion_getInstance_0()).om(), serializer_2(Companion_getInstance_1()).om(), serializer_3(Companion_getInstance_2()).om()]);
  }
}
function get_ESCAPE_STRINGS() {
  _init_properties_StringOps_kt__fcy1db();
  return ESCAPE_STRINGS;
}
var ESCAPE_STRINGS;
var ESCAPE_MARKERS;
function toHexChar(i) {
  _init_properties_StringOps_kt__fcy1db();
  var d = i & 15;
  var tmp;
  if (d < 10) {
    // Inline function 'kotlin.code' call
    var this_0 = _Char___init__impl__6a9atx(48);
    var tmp$ret$0 = Char__toInt_impl_vasixd(this_0);
    tmp = numberToChar(d + tmp$ret$0 | 0);
  } else {
    var tmp_0 = d - 10 | 0;
    // Inline function 'kotlin.code' call
    var this_1 = _Char___init__impl__6a9atx(97);
    var tmp$ret$1 = Char__toInt_impl_vasixd(this_1);
    tmp = numberToChar(tmp_0 + tmp$ret$1 | 0);
  }
  return tmp;
}
function printQuoted(_this__u8e3s4, value) {
  _init_properties_StringOps_kt__fcy1db();
  _this__u8e3s4.t9(_Char___init__impl__6a9atx(34));
  var lastPos = 0;
  var inductionVariable = 0;
  var last = charSequenceLength(value) - 1 | 0;
  if (inductionVariable <= last)
    do {
      var i = inductionVariable;
      inductionVariable = inductionVariable + 1 | 0;
      // Inline function 'kotlin.code' call
      var this_0 = charCodeAt(value, i);
      var c = Char__toInt_impl_vasixd(this_0);
      if (c < get_ESCAPE_STRINGS().length && !(get_ESCAPE_STRINGS()[c] == null)) {
        _this__u8e3s4.rd(value, lastPos, i);
        _this__u8e3s4.s9(get_ESCAPE_STRINGS()[c]);
        lastPos = i + 1 | 0;
      }
    }
     while (inductionVariable <= last);
  if (!(lastPos === 0))
    _this__u8e3s4.rd(value, lastPos, value.length);
  else
    _this__u8e3s4.s9(value);
  _this__u8e3s4.t9(_Char___init__impl__6a9atx(34));
}
function toBooleanStrictOrNull(_this__u8e3s4) {
  _init_properties_StringOps_kt__fcy1db();
  return equals_0(_this__u8e3s4, 'true', true) ? true : equals_0(_this__u8e3s4, 'false', true) ? false : null;
}
var properties_initialized_StringOps_kt_wzaea7;
function _init_properties_StringOps_kt__fcy1db() {
  if (!properties_initialized_StringOps_kt_wzaea7) {
    properties_initialized_StringOps_kt_wzaea7 = true;
    // Inline function 'kotlin.arrayOfNulls' call
    // Inline function 'kotlin.apply' call
    var this_0 = Array(93);
    var inductionVariable = 0;
    if (inductionVariable <= 31)
      do {
        var c = inductionVariable;
        inductionVariable = inductionVariable + 1 | 0;
        var c1 = toHexChar(c >> 12);
        var c2 = toHexChar(c >> 8);
        var c3 = toHexChar(c >> 4);
        var c4 = toHexChar(c);
        this_0[c] = '\\u' + toString_1(c1) + toString_1(c2) + toString_1(c3) + toString_1(c4);
      }
       while (inductionVariable <= 31);
    // Inline function 'kotlin.code' call
    var this_1 = _Char___init__impl__6a9atx(34);
    this_0[Char__toInt_impl_vasixd(this_1)] = '\\"';
    // Inline function 'kotlin.code' call
    var this_2 = _Char___init__impl__6a9atx(92);
    this_0[Char__toInt_impl_vasixd(this_2)] = '\\\\';
    // Inline function 'kotlin.code' call
    var this_3 = _Char___init__impl__6a9atx(9);
    this_0[Char__toInt_impl_vasixd(this_3)] = '\\t';
    // Inline function 'kotlin.code' call
    var this_4 = _Char___init__impl__6a9atx(8);
    this_0[Char__toInt_impl_vasixd(this_4)] = '\\b';
    // Inline function 'kotlin.code' call
    var this_5 = _Char___init__impl__6a9atx(10);
    this_0[Char__toInt_impl_vasixd(this_5)] = '\\n';
    // Inline function 'kotlin.code' call
    var this_6 = _Char___init__impl__6a9atx(13);
    this_0[Char__toInt_impl_vasixd(this_6)] = '\\r';
    this_0[12] = '\\f';
    ESCAPE_STRINGS = this_0;
    // Inline function 'kotlin.apply' call
    var this_7 = new Int8Array(93);
    var inductionVariable_0 = 0;
    if (inductionVariable_0 <= 31)
      do {
        var c_0 = inductionVariable_0;
        inductionVariable_0 = inductionVariable_0 + 1 | 0;
        this_7[c_0] = 1;
      }
       while (inductionVariable_0 <= 31);
    // Inline function 'kotlin.code' call
    var this_8 = _Char___init__impl__6a9atx(34);
    var tmp = Char__toInt_impl_vasixd(this_8);
    // Inline function 'kotlin.code' call
    var this_9 = _Char___init__impl__6a9atx(34);
    var tmp$ret$3 = Char__toInt_impl_vasixd(this_9);
    this_7[tmp] = toByte(tmp$ret$3);
    // Inline function 'kotlin.code' call
    var this_10 = _Char___init__impl__6a9atx(92);
    var tmp_0 = Char__toInt_impl_vasixd(this_10);
    // Inline function 'kotlin.code' call
    var this_11 = _Char___init__impl__6a9atx(92);
    var tmp$ret$5 = Char__toInt_impl_vasixd(this_11);
    this_7[tmp_0] = toByte(tmp$ret$5);
    // Inline function 'kotlin.code' call
    var this_12 = _Char___init__impl__6a9atx(9);
    var tmp_1 = Char__toInt_impl_vasixd(this_12);
    // Inline function 'kotlin.code' call
    var this_13 = _Char___init__impl__6a9atx(116);
    var tmp$ret$7 = Char__toInt_impl_vasixd(this_13);
    this_7[tmp_1] = toByte(tmp$ret$7);
    // Inline function 'kotlin.code' call
    var this_14 = _Char___init__impl__6a9atx(8);
    var tmp_2 = Char__toInt_impl_vasixd(this_14);
    // Inline function 'kotlin.code' call
    var this_15 = _Char___init__impl__6a9atx(98);
    var tmp$ret$9 = Char__toInt_impl_vasixd(this_15);
    this_7[tmp_2] = toByte(tmp$ret$9);
    // Inline function 'kotlin.code' call
    var this_16 = _Char___init__impl__6a9atx(10);
    var tmp_3 = Char__toInt_impl_vasixd(this_16);
    // Inline function 'kotlin.code' call
    var this_17 = _Char___init__impl__6a9atx(110);
    var tmp$ret$11 = Char__toInt_impl_vasixd(this_17);
    this_7[tmp_3] = toByte(tmp$ret$11);
    // Inline function 'kotlin.code' call
    var this_18 = _Char___init__impl__6a9atx(13);
    var tmp_4 = Char__toInt_impl_vasixd(this_18);
    // Inline function 'kotlin.code' call
    var this_19 = _Char___init__impl__6a9atx(114);
    var tmp$ret$13 = Char__toInt_impl_vasixd(this_19);
    this_7[tmp_4] = toByte(tmp$ret$13);
    // Inline function 'kotlin.code' call
    var this_20 = _Char___init__impl__6a9atx(102);
    var tmp$ret$14 = Char__toInt_impl_vasixd(this_20);
    this_7[12] = toByte(tmp$ret$14);
    ESCAPE_MARKERS = this_7;
  }
}
function readJson(json, element, deserializer) {
  var tmp;
  if (element instanceof JsonObject) {
    tmp = new JsonTreeDecoder(json, element);
  } else {
    if (element instanceof JsonArray) {
      tmp = new JsonTreeListDecoder(json, element);
    } else {
      var tmp_0;
      if (element instanceof JsonLiteral) {
        tmp_0 = true;
      } else {
        tmp_0 = equals(element, JsonNull_getInstance());
      }
      if (tmp_0) {
        tmp = new JsonPrimitiveDecoder(json, element instanceof JsonPrimitive ? element : THROW_CCE());
      } else {
        noWhenBranchMatchedException();
      }
    }
  }
  var input = tmp;
  return input.yp(deserializer);
}
function readPolymorphicJson(_this__u8e3s4, discriminator, element, deserializer) {
  return (new JsonTreeDecoder(_this__u8e3s4, element, discriminator, deserializer.om())).yp(deserializer);
}
function unparsedPrimitive($this, literal, primitive, tag) {
  var type = startsWith(primitive, 'i') ? 'an ' + primitive : 'a ' + primitive;
  var tmp2 = "Failed to parse literal '" + literal.toString() + "' as " + type + ' value';
  // Inline function 'kotlinx.serialization.json.internal.decodingExceptionOf' call
  var path = $this.h18(tag);
  var tmp;
  if ($this.r13().l11_1.q13_1) {
    var tmp$ret$3 = toString($this.i18());
    tmp = toString(minify(tmp$ret$3));
  } else {
    tmp = null;
  }
  var inputValue = tmp;
  throw JsonDecodingException.e15(access$formatDecodingException$tJsonExceptionsKt(-1, tmp2, path, null, inputValue), tmp2, -1, path, inputValue, null);
}
function setForceNull($this, descriptor, index) {
  $this.f19_1 = (!$this.r13().l11_1.e13_1 && !descriptor.fo(index) && descriptor.eo(index).qn());
  return $this.f19_1;
}
var WriteMode_OBJ_instance;
var WriteMode_LIST_instance;
var WriteMode_MAP_instance;
var WriteMode_POLY_OBJ_instance;
var WriteMode_entriesInitialized;
function WriteMode_initEntries() {
  if (WriteMode_entriesInitialized)
    return Unit_instance;
  WriteMode_entriesInitialized = true;
  WriteMode_OBJ_instance = new WriteMode('OBJ', 0, _Char___init__impl__6a9atx(123), _Char___init__impl__6a9atx(125));
  WriteMode_LIST_instance = new WriteMode('LIST', 1, _Char___init__impl__6a9atx(91), _Char___init__impl__6a9atx(93));
  WriteMode_MAP_instance = new WriteMode('MAP', 2, _Char___init__impl__6a9atx(123), _Char___init__impl__6a9atx(125));
  WriteMode_POLY_OBJ_instance = new WriteMode('POLY_OBJ', 3, _Char___init__impl__6a9atx(91), _Char___init__impl__6a9atx(93));
}
function switchMode(_this__u8e3s4, desc) {
  var tmp0_subject = desc.xn();
  var tmp;
  if (tmp0_subject instanceof PolymorphicKind) {
    tmp = WriteMode_POLY_OBJ_getInstance();
  } else {
    if (equals(tmp0_subject, LIST_getInstance())) {
      tmp = WriteMode_LIST_getInstance();
    } else {
      if (equals(tmp0_subject, MAP_getInstance())) {
        // Inline function 'kotlinx.serialization.json.internal.selectMapMode' call
        var keyDescriptor = carrierDescriptor(desc.eo(0), _this__u8e3s4.oq());
        var keyKind = keyDescriptor.xn();
        var tmp_0;
        var tmp_1;
        if (keyKind instanceof PrimitiveKind) {
          tmp_1 = true;
        } else {
          tmp_1 = equals(keyKind, ENUM_getInstance());
        }
        if (tmp_1) {
          tmp_0 = WriteMode_MAP_getInstance();
        } else {
          if (_this__u8e3s4.l11_1.c13_1) {
            tmp_0 = WriteMode_LIST_getInstance();
          } else {
            throw InvalidKeyKindException(keyDescriptor);
          }
        }
        tmp = tmp_0;
      } else {
        tmp = WriteMode_OBJ_getInstance();
      }
    }
  }
  return tmp;
}
function carrierDescriptor(_this__u8e3s4, module_0) {
  var tmp;
  if (equals(_this__u8e3s4.xn(), CONTEXTUAL_getInstance())) {
    var tmp0_safe_receiver = getContextualDescriptor(module_0, _this__u8e3s4);
    var tmp1_elvis_lhs = tmp0_safe_receiver == null ? null : carrierDescriptor(tmp0_safe_receiver, module_0);
    tmp = tmp1_elvis_lhs == null ? _this__u8e3s4 : tmp1_elvis_lhs;
  } else if (_this__u8e3s4.yn()) {
    tmp = carrierDescriptor(_this__u8e3s4.eo(0), module_0);
  } else {
    tmp = _this__u8e3s4;
  }
  return tmp;
}
function WriteMode_OBJ_getInstance() {
  WriteMode_initEntries();
  return WriteMode_OBJ_instance;
}
function WriteMode_LIST_getInstance() {
  WriteMode_initEntries();
  return WriteMode_LIST_instance;
}
function WriteMode_MAP_getInstance() {
  WriteMode_initEntries();
  return WriteMode_MAP_instance;
}
function WriteMode_POLY_OBJ_getInstance() {
  WriteMode_initEntries();
  return WriteMode_POLY_OBJ_instance;
}
function appendEscape($this, lastPosition, current) {
  $this.l1a(lastPosition, current);
  return appendEsc($this, current + 1 | 0);
}
function decodedString($this, lastPosition, currentPosition) {
  $this.l1a(lastPosition, currentPosition);
  var result = $this.d12_1.toString();
  $this.d12_1.yd(0);
  return result;
}
function takePeeked($this) {
  // Inline function 'kotlin.also' call
  var this_0 = ensureNotNull($this.c12_1);
  $this.c12_1 = null;
  return this_0;
}
function wasUnquotedString($this) {
  return !(charSequenceGet($this.m1a(), $this.a12_1 - 1 | 0) === _Char___init__impl__6a9atx(34));
}
function appendEsc($this, startPosition) {
  var currentPosition = startPosition;
  currentPosition = $this.n1a(currentPosition);
  if (currentPosition === -1) {
    $this.d16('Expected escape sequence to continue, got EOF');
  }
  var tmp = $this.m1a();
  var _unary__edvuaz = currentPosition;
  currentPosition = _unary__edvuaz + 1 | 0;
  var currentChar = charSequenceGet(tmp, _unary__edvuaz);
  if (currentChar === _Char___init__impl__6a9atx(117)) {
    return appendHex($this, $this.m1a(), currentPosition);
  }
  // Inline function 'kotlin.code' call
  var tmp$ret$0 = Char__toInt_impl_vasixd(currentChar);
  var c = escapeToChar(tmp$ret$0);
  if (c === _Char___init__impl__6a9atx(0)) {
    $this.d16("Invalid escaped char '" + toString_1(currentChar) + "'");
  }
  $this.d12_1.t9(c);
  return currentPosition;
}
function appendHex($this, source, startPos) {
  if ((startPos + 4 | 0) >= charSequenceLength(source)) {
    $this.a12_1 = startPos;
    $this.o1a();
    if (($this.a12_1 + 4 | 0) >= charSequenceLength(source)) {
      $this.d16('Unexpected EOF during unicode escape');
    }
    return appendHex($this, source, $this.a12_1);
  }
  $this.d12_1.t9(numberToChar((((fromHexChar($this, source, startPos) << 12) + (fromHexChar($this, source, startPos + 1 | 0) << 8) | 0) + (fromHexChar($this, source, startPos + 2 | 0) << 4) | 0) + fromHexChar($this, source, startPos + 3 | 0) | 0));
  return startPos + 4 | 0;
}
function fromHexChar($this, source, currentPosition) {
  var character = charSequenceGet(source, currentPosition);
  var tmp;
  if (_Char___init__impl__6a9atx(48) <= character ? character <= _Char___init__impl__6a9atx(57) : false) {
    // Inline function 'kotlin.code' call
    var tmp_0 = Char__toInt_impl_vasixd(character);
    // Inline function 'kotlin.code' call
    var this_0 = _Char___init__impl__6a9atx(48);
    tmp = tmp_0 - Char__toInt_impl_vasixd(this_0) | 0;
  } else if (_Char___init__impl__6a9atx(97) <= character ? character <= _Char___init__impl__6a9atx(102) : false) {
    // Inline function 'kotlin.code' call
    var tmp_1 = Char__toInt_impl_vasixd(character);
    // Inline function 'kotlin.code' call
    var this_1 = _Char___init__impl__6a9atx(97);
    tmp = (tmp_1 - Char__toInt_impl_vasixd(this_1) | 0) + 10 | 0;
  } else if (_Char___init__impl__6a9atx(65) <= character ? character <= _Char___init__impl__6a9atx(70) : false) {
    // Inline function 'kotlin.code' call
    var tmp_2 = Char__toInt_impl_vasixd(character);
    // Inline function 'kotlin.code' call
    var this_2 = _Char___init__impl__6a9atx(65);
    tmp = (tmp_2 - Char__toInt_impl_vasixd(this_2) | 0) + 10 | 0;
  } else {
    $this.d16("Invalid toHexChar char '" + toString_1(character) + "' in unicode escape");
  }
  return tmp;
}
function consumeBoolean2($this, start) {
  var current = $this.n1a(start);
  if (current >= charSequenceLength($this.m1a()) || current === -1) {
    $this.d16('EOF');
  }
  var tmp = $this.m1a();
  var _unary__edvuaz = current;
  current = _unary__edvuaz + 1 | 0;
  // Inline function 'kotlin.code' call
  var this_0 = charSequenceGet(tmp, _unary__edvuaz);
  var tmp0_subject = Char__toInt_impl_vasixd(this_0) | 32;
  var tmp_0;
  // Inline function 'kotlin.code' call
  var this_1 = _Char___init__impl__6a9atx(116);
  if (tmp0_subject === Char__toInt_impl_vasixd(this_1)) {
    consumeBooleanLiteral($this, 'rue', current);
    tmp_0 = true;
  } else {
    // Inline function 'kotlin.code' call
    var this_2 = _Char___init__impl__6a9atx(102);
    if (tmp0_subject === Char__toInt_impl_vasixd(this_2)) {
      consumeBooleanLiteral($this, 'alse', current);
      tmp_0 = false;
    } else {
      $this.d16("Expected valid boolean literal prefix, but had '" + $this.c17() + "'");
    }
  }
  return tmp_0;
}
function consumeBooleanLiteral($this, literalSuffix, current) {
  if ((charSequenceLength($this.m1a()) - current | 0) < literalSuffix.length) {
    $this.d16('Unexpected end of boolean literal');
  }
  var inductionVariable = 0;
  var last = charSequenceLength(literalSuffix) - 1 | 0;
  if (inductionVariable <= last)
    do {
      var i = inductionVariable;
      inductionVariable = inductionVariable + 1 | 0;
      var expected = charCodeAt(literalSuffix, i);
      var actual = charSequenceGet($this.m1a(), current + i | 0);
      // Inline function 'kotlin.code' call
      var tmp = Char__toInt_impl_vasixd(expected);
      // Inline function 'kotlin.code' call
      if (!(tmp === (Char__toInt_impl_vasixd(actual) | 32))) {
        $this.d16("Expected valid boolean literal prefix, but had '" + $this.c17() + "'");
      }
    }
     while (inductionVariable <= last);
  $this.a12_1 = current + literalSuffix.length | 0;
}
function consumeNumericLiteral$calculateExponent(exponentAccumulator, isExponentPositive) {
  var tmp;
  switch (isExponentPositive) {
    case false:
      // Inline function 'kotlin.math.pow' call

      var x = -toNumber(exponentAccumulator);
      tmp = Math.pow(10.0, x);
      break;
    case true:
      // Inline function 'kotlin.math.pow' call

      var x_0 = toNumber(exponentAccumulator);
      tmp = Math.pow(10.0, x_0);
      break;
    default:
      noWhenBranchMatchedException();
      break;
  }
  return tmp;
}
function charToTokenClass(c) {
  var tmp;
  // Inline function 'kotlin.code' call
  if (Char__toInt_impl_vasixd(c) < 126) {
    var tmp_0 = CharMappings_getInstance().v1a_1;
    // Inline function 'kotlin.code' call
    tmp = tmp_0[Char__toInt_impl_vasixd(c)];
  } else {
    tmp = 0;
  }
  return tmp;
}
function tokenDescription(token) {
  return token === 1 ? "quotation mark '\"'" : token === 2 ? "string escape sequence '\\'" : token === 4 ? "comma ','" : token === 5 ? "colon ':'" : token === 6 ? "start of the object '{'" : token === 7 ? "end of the object '}'" : token === 8 ? "start of the array '['" : token === 9 ? "end of the array ']'" : token === 10 ? 'end of the input' : token === 127 ? 'invalid token' : 'valid token';
}
function escapeToChar(c) {
  return c < 117 ? CharMappings_getInstance().u1a_1[c] : _Char___init__impl__6a9atx(0);
}
function initEscape($this) {
  var inductionVariable = 0;
  if (inductionVariable <= 31)
    do {
      var i = inductionVariable;
      inductionVariable = inductionVariable + 1 | 0;
      initC2ESC($this, i, _Char___init__impl__6a9atx(117));
    }
     while (inductionVariable <= 31);
  initC2ESC($this, 8, _Char___init__impl__6a9atx(98));
  initC2ESC($this, 9, _Char___init__impl__6a9atx(116));
  initC2ESC($this, 10, _Char___init__impl__6a9atx(110));
  initC2ESC($this, 12, _Char___init__impl__6a9atx(102));
  initC2ESC($this, 13, _Char___init__impl__6a9atx(114));
  initC2ESC_0($this, _Char___init__impl__6a9atx(47), _Char___init__impl__6a9atx(47));
  initC2ESC_0($this, _Char___init__impl__6a9atx(34), _Char___init__impl__6a9atx(34));
  initC2ESC_0($this, _Char___init__impl__6a9atx(92), _Char___init__impl__6a9atx(92));
}
function initCharToToken($this) {
  var inductionVariable = 0;
  if (inductionVariable <= 32)
    do {
      var i = inductionVariable;
      inductionVariable = inductionVariable + 1 | 0;
      initC2TC($this, i, 127);
    }
     while (inductionVariable <= 32);
  initC2TC($this, 9, 3);
  initC2TC($this, 10, 3);
  initC2TC($this, 13, 3);
  initC2TC($this, 32, 3);
  initC2TC_0($this, _Char___init__impl__6a9atx(44), 4);
  initC2TC_0($this, _Char___init__impl__6a9atx(58), 5);
  initC2TC_0($this, _Char___init__impl__6a9atx(123), 6);
  initC2TC_0($this, _Char___init__impl__6a9atx(125), 7);
  initC2TC_0($this, _Char___init__impl__6a9atx(91), 8);
  initC2TC_0($this, _Char___init__impl__6a9atx(93), 9);
  initC2TC_0($this, _Char___init__impl__6a9atx(34), 1);
  initC2TC_0($this, _Char___init__impl__6a9atx(92), 2);
}
function initC2ESC($this, c, esc) {
  if (!(esc === _Char___init__impl__6a9atx(117))) {
    // Inline function 'kotlin.code' call
    var tmp$ret$0 = Char__toInt_impl_vasixd(esc);
    $this.u1a_1[tmp$ret$0] = numberToChar(c);
  }
}
function initC2ESC_0($this, c, esc) {
  // Inline function 'kotlin.code' call
  var tmp$ret$0 = Char__toInt_impl_vasixd(c);
  return initC2ESC($this, tmp$ret$0, esc);
}
function initC2TC($this, c, cl) {
  $this.v1a_1[c] = cl;
}
function initC2TC_0($this, c, cl) {
  // Inline function 'kotlin.code' call
  var tmp$ret$0 = Char__toInt_impl_vasixd(c);
  return initC2TC($this, tmp$ret$0, cl);
}
var CharMappings_instance;
function CharMappings_getInstance() {
  if (CharMappings_instance === VOID)
    new CharMappings();
  return CharMappings_instance;
}
function StringJsonLexer_0(json, source) {
  return !json.l11_1.o13_1 ? new StringJsonLexer(source, json.l11_1) : new StringJsonLexerWithComments(source, json.l11_1);
}
function get_schemaCache(_this__u8e3s4) {
  return _this__u8e3s4.n11_1;
}
function createMapForCache(initialCapacity) {
  return HashMap.b7(initialCapacity);
}
//region block: post-declaration
initMetadataForClass(Json, 'Json');
initMetadataForObject(Default, 'Default');
initMetadataForClass(JsonBuilder, 'JsonBuilder');
initMetadataForClass(JsonImpl, 'JsonImpl');
initMetadataForClass(JsonClassDiscriminator, 'JsonClassDiscriminator');
initMetadataForClass(JsonIgnoreUnknownKeys, 'JsonIgnoreUnknownKeys');
initMetadataForClass(JsonNames, 'JsonNames');
initMetadataForClass(JsonConfiguration, 'JsonConfiguration');
initMetadataForClass(ClassDiscriminatorMode, 'ClassDiscriminatorMode');
initMetadataForInterface(JsonDecoder, 'JsonDecoder', VOID, VOID, [Decoder, CompositeDecoder]);
initMetadataForCompanion(Companion);
initMetadataForClass(JsonElement, 'JsonElement', VOID, VOID, VOID, VOID, VOID, {0: JsonElementSerializer_getInstance});
initMetadataForClass(JsonArray, 'JsonArray', VOID, VOID, [KtList], VOID, VOID, {0: JsonArraySerializer_getInstance});
initMetadataForCompanion(Companion_0);
initMetadataForCompanion(Companion_1);
initMetadataForClass(JsonObject, 'JsonObject', VOID, VOID, [KtMap], VOID, VOID, {0: JsonObjectSerializer_getInstance});
initMetadataForCompanion(Companion_2);
initMetadataForClass(JsonPrimitive, 'JsonPrimitive', VOID, VOID, VOID, VOID, VOID, {0: JsonPrimitiveSerializer_getInstance});
initMetadataForObject(JsonNull, 'JsonNull', VOID, VOID, VOID, VOID, VOID, {0: JsonNullSerializer_getInstance});
initMetadataForClass(JsonLiteral, 'JsonLiteral');
initMetadataForClass(JsonObjectBuilder, 'JsonObjectBuilder');
initMetadataForClass(JsonArrayBuilder, 'JsonArrayBuilder');
initMetadataForObject(JsonArrayDescriptor, 'JsonArrayDescriptor', VOID, VOID, [SerialDescriptor]);
initMetadataForObject(JsonArraySerializer, 'JsonArraySerializer', VOID, VOID, [KSerializer]);
initMetadataForObject(JsonElementSerializer, 'JsonElementSerializer', VOID, VOID, [KSerializer]);
initMetadataForObject(JsonObjectDescriptor, 'JsonObjectDescriptor', VOID, VOID, [SerialDescriptor]);
initMetadataForObject(JsonObjectSerializer, 'JsonObjectSerializer', VOID, VOID, [KSerializer]);
initMetadataForObject(JsonPrimitiveSerializer, 'JsonPrimitiveSerializer', VOID, VOID, [KSerializer]);
initMetadataForObject(JsonNullSerializer, 'JsonNullSerializer', VOID, VOID, [KSerializer]);
initMetadataForObject(JsonLiteralSerializer, 'JsonLiteralSerializer', VOID, VOID, [KSerializer]);
protoOf(defer$1).qn = get_isNullable;
protoOf(defer$1).yn = get_isInline;
protoOf(defer$1).ao = get_annotations;
initMetadataForClass(defer$1, VOID, VOID, VOID, [SerialDescriptor]);
initMetadataForClass(JsonException, 'JsonException');
initMetadataForClass(JsonDecodingException, 'JsonDecodingException');
initMetadataForClass(JsonEncodingException, 'JsonEncodingException');
initMetadataForClass(JsonElementMarker, 'JsonElementMarker');
initMetadataForObject(Tombstone, 'Tombstone');
initMetadataForObject(RedactedKey, 'RedactedKey');
initMetadataForClass(JsonPath, 'JsonPath');
protoOf(JsonSerializersModuleValidator).h11 = contextual;
initMetadataForClass(JsonSerializersModuleValidator, 'JsonSerializersModuleValidator', VOID, VOID, [SerializersModuleCollector]);
initMetadataForClass(JsonTreeReader, 'JsonTreeReader', VOID, VOID, VOID, [1]);
initMetadataForClass(Key, 'Key', Key);
initMetadataForClass(DescriptorSchemaCache, 'DescriptorSchemaCache', DescriptorSchemaCache);
initMetadataForClass(DiscriminatorHolder, 'DiscriminatorHolder');
initMetadataForClass(StreamingJsonDecoder, 'StreamingJsonDecoder', VOID, VOID, [JsonDecoder]);
initMetadataForClass(JsonDecoderForUnsignedTypes, 'JsonDecoderForUnsignedTypes');
initMetadataForClass(AbstractJsonTreeDecoder, 'AbstractJsonTreeDecoder', VOID, VOID, [JsonDecoder]);
initMetadataForClass(JsonTreeDecoder, 'JsonTreeDecoder');
initMetadataForClass(JsonTreeListDecoder, 'JsonTreeListDecoder');
initMetadataForClass(JsonPrimitiveDecoder, 'JsonPrimitiveDecoder');
initMetadataForClass(JsonTreeMapDecoder, 'JsonTreeMapDecoder');
initMetadataForClass(WriteMode, 'WriteMode');
initMetadataForClass(AbstractJsonLexer, 'AbstractJsonLexer');
initMetadataForObject(CharMappings, 'CharMappings');
initMetadataForClass(StringJsonLexer, 'StringJsonLexer');
initMetadataForClass(StringJsonLexerWithComments, 'StringJsonLexerWithComments');
//endregion
//region block: init
Companion_instance = new Companion();
Companion_instance_0 = new Companion_0();
Companion_instance_1 = new Companion_1();
Companion_instance_2 = new Companion_2();
Tombstone_instance = new Tombstone();
RedactedKey_instance = new RedactedKey();
//endregion
//region block: exports
export {
  JsonNull_getInstance as JsonNull_getInstance39w6eplghmtxw,
  JsonArrayBuilder as JsonArrayBuilderu8edol6ui3pj,
  JsonArray as JsonArray2urf8ey7u44sd,
  JsonObjectBuilder as JsonObjectBuilder2nl6rv6vdayuk,
  JsonPrimitive_1 as JsonPrimitiveolttw629wj53,
  JsonPrimitive_0 as JsonPrimitive2fp8648nd60dn,
  Json_0 as Jsonsmkyu9xjl7fv,
  get_contentOrNull as get_contentOrNull35s97cgi8z9eo,
  get_jsonObject as get_jsonObject2u4z2ch1uuca9,
  get_jsonPrimitive as get_jsonPrimitivez17tyd5rw1ql,
  putJsonArray as putJsonArray1vg6msz2wcer6,
  put_0 as puthzp5cbwyvxpw,
  put as put2xyujhcf0ewjd,
  put_1 as put3nck2c3wvxqib,
};
//endregion

//# sourceMappingURL=kotlinx-serialization-kotlinx-serialization-json.mjs.map
