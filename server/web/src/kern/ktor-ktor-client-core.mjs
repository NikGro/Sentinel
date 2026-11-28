import {
  initMetadataForObject1cxne3s9w65el as initMetadataForObject,
  Unit_instance3vdlo4e4f5ggx as Unit_instance,
  initMetadataForClassbxx6q50dy2s7 as initMetadataForClass,
  ensureNotNull1e947j3ixpazm as ensureNotNull,
  VOID3gxj6tk5isa35 as VOID,
} from './kotlin-kotlin-stdlib.mjs';
import { atomic$ref$130aurmcwdfdf1 as atomic$ref$1 } from './kotlinx-atomicfu.mjs';
//region block: imports
//endregion
//region block: pre-declaration
class Js {
  toString() {
    return 'Js';
  }
  hashCode() {
    return -527824213;
  }
  equals(other) {
    if (this === other)
      return true;
    if (!(other instanceof Js))
      return false;
    return true;
  }
}
class Node {
  constructor(item, next) {
    this.e1c_1 = item;
    this.f1c_1 = next;
  }
}
class engines$iterator$1 {
  constructor() {
    this.g1c_1 = engines_getInstance().c1c_1.kotlinx$atomicfu$value;
  }
  y() {
    var result = ensureNotNull(this.g1c_1);
    this.g1c_1 = result.f1c_1;
    return result.e1c_1;
  }
  x() {
    return !(null == this.g1c_1);
  }
}
class engines {
  constructor() {
    engines_instance = this;
    this.c1c_1 = atomic$ref$1(null);
  }
  d1c(item) {
    $l$loop: while (true) {
      var current = this.c1c_1.kotlinx$atomicfu$value;
      var new_0 = new Node(item, current);
      if (this.c1c_1.atomicfu$compareAndSet(current, new_0))
        break $l$loop;
    }
  }
  w() {
    return new engines$iterator$1();
  }
}
//endregion
function get_initHook() {
  return initHook;
}
var initHook;
var Js_instance;
function Js_getInstance() {
  return Js_instance;
}
function initHook$init$() {
  engines_getInstance().d1c(Js_instance);
  return Unit_instance;
}
var engines_instance;
function engines_getInstance() {
  if (engines_instance === VOID)
    new engines();
  return engines_instance;
}
//region block: post-declaration
initMetadataForObject(Js, 'Js');
initMetadataForClass(Node, 'Node');
initMetadataForClass(engines$iterator$1);
initMetadataForObject(engines, 'engines');
//endregion
//region block: init
Js_instance = new Js();
//endregion
//region block: eager init
initHook = initHook$init$();
//endregion
//region block: exports
var initHook_0 = {get: get_initHook};
export {
  initHook_0 as initHook,
};
//endregion

//# sourceMappingURL=ktor-ktor-client-core.mjs.map
