import {
  Continuation1aa2oekvx7jm7 as Continuation,
  initMetadataForClassbxx6q50dy2s7 as initMetadataForClass,
  VOID3gxj6tk5isa35 as VOID,
  equals2au1ep9vhcato as equals,
  Unit_instance3vdlo4e4f5ggx as Unit_instance,
} from './kotlin-kotlin-stdlib.mjs';
import { atomic$ref$130aurmcwdfdf1 as atomic$ref$1 } from './kotlinx-atomicfu.mjs';
//region block: imports
//endregion
//region block: pre-declaration
class SchedulerTask {}
class DispatchedTask extends SchedulerTask {}
class CancellableContinuationImpl extends DispatchedTask {}
class SynchronizedObject {}
class AbstractSharedFlow extends SynchronizedObject {
  constructor() {
    super();
    this.q1b_1 = null;
    this.r1b_1 = 0;
    this.s1b_1 = 0;
    this.t1b_1 = null;
  }
}
class StateFlowImpl extends AbstractSharedFlow {
  constructor(initialState) {
    super();
    this.o1b_1 = atomic$ref$1(initialState);
    this.p1b_1 = 0;
  }
  w1b(value) {
    updateState(this, null, value == null ? get_NULL() : value);
  }
  h2() {
    var tmp0 = get_NULL();
    // Inline function 'kotlinx.coroutines.internal.Symbol.unbox' call
    var value = this.o1b_1.kotlinx$atomicfu$value;
    return value === tmp0 ? null : value;
  }
}
class ReadonlyStateFlow {
  constructor(flow, job) {
    this.x1b_1 = flow;
    this.y1b_1 = job;
  }
  h2() {
    return this.x1b_1.h2();
  }
}
class Symbol {
  constructor(symbol) {
    this.b1c_1 = symbol;
  }
  toString() {
    return '<' + this.b1c_1 + '>';
  }
}
//endregion
function get_NONE() {
  _init_properties_StateFlow_kt__eu9yi5();
  return NONE;
}
var NONE;
function get_PENDING() {
  _init_properties_StateFlow_kt__eu9yi5();
  return PENDING;
}
var PENDING;
function MutableStateFlow(value) {
  _init_properties_StateFlow_kt__eu9yi5();
  return new StateFlowImpl(value == null ? get_NULL() : value);
}
function updateState($this, expectedState, newState) {
  var curSequence;
  var curSlots;
  // Inline function 'kotlinx.coroutines.internal.synchronized' call
  // Inline function 'kotlinx.coroutines.internal.synchronizedImpl' call
  var oldState = $this.o1b_1.kotlinx$atomicfu$value;
  if (!(expectedState == null) && !equals(oldState, expectedState))
    return false;
  if (equals(oldState, newState))
    return true;
  $this.o1b_1.kotlinx$atomicfu$value = newState;
  curSequence = $this.p1b_1;
  if ((curSequence & 1) === 0) {
    curSequence = curSequence + 1 | 0;
    $this.p1b_1 = curSequence;
  } else {
    $this.p1b_1 = curSequence + 2 | 0;
    return true;
  }
  curSlots = $this.q1b_1;
  while (true) {
    var tmp0_safe_receiver = curSlots;
    if (tmp0_safe_receiver == null)
      null;
    else {
      // Inline function 'kotlin.collections.forEach' call
      var inductionVariable = 0;
      var last = tmp0_safe_receiver.length;
      while (inductionVariable < last) {
        var element = tmp0_safe_receiver[inductionVariable];
        inductionVariable = inductionVariable + 1 | 0;
        if (element == null)
          null;
        else {
          element.v1b();
        }
      }
    }
    // Inline function 'kotlinx.coroutines.internal.synchronized' call
    // Inline function 'kotlinx.coroutines.internal.synchronizedImpl' call
    if ($this.p1b_1 === curSequence) {
      $this.p1b_1 = curSequence + 1 | 0;
      return true;
    }
    curSequence = $this.p1b_1;
    curSlots = $this.q1b_1;
  }
}
var properties_initialized_StateFlow_kt_nsqikx;
function _init_properties_StateFlow_kt__eu9yi5() {
  if (!properties_initialized_StateFlow_kt_nsqikx) {
    properties_initialized_StateFlow_kt_nsqikx = true;
    NONE = new Symbol('NONE');
    PENDING = new Symbol('PENDING');
  }
}
function get_NULL() {
  _init_properties_NullSurrogate_kt__n2yti9();
  return NULL;
}
var NULL;
var UNINITIALIZED;
var DONE;
var properties_initialized_NullSurrogate_kt_39v8bl;
function _init_properties_NullSurrogate_kt__n2yti9() {
  if (!properties_initialized_NullSurrogate_kt_39v8bl) {
    properties_initialized_NullSurrogate_kt_39v8bl = true;
    NULL = new Symbol('NULL');
    UNINITIALIZED = new Symbol('UNINITIALIZED');
    DONE = new Symbol('DONE');
  }
}
function asStateFlow(_this__u8e3s4) {
  return new ReadonlyStateFlow(_this__u8e3s4, null);
}
function get_value(_this__u8e3s4) {
  return _this__u8e3s4.a1c();
}
//region block: post-declaration
initMetadataForClass(SchedulerTask, 'SchedulerTask');
initMetadataForClass(DispatchedTask, 'DispatchedTask');
initMetadataForClass(CancellableContinuationImpl, 'CancellableContinuationImpl', VOID, VOID, [Continuation]);
initMetadataForClass(SynchronizedObject, 'SynchronizedObject', SynchronizedObject);
initMetadataForClass(AbstractSharedFlow, 'AbstractSharedFlow');
initMetadataForClass(StateFlowImpl, 'StateFlowImpl', VOID, VOID, VOID, [1]);
initMetadataForClass(ReadonlyStateFlow, 'ReadonlyStateFlow', VOID, VOID, VOID, [1]);
initMetadataForClass(Symbol, 'Symbol');
//endregion
//region block: exports
export {
  MutableStateFlow as MutableStateFlow34bfoyvwu8czu,
  asStateFlow as asStateFlow34rribx643ke5,
};
//endregion

//# sourceMappingURL=kotlinx-coroutines-core.mjs.map
