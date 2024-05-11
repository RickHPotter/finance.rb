import{Controller as t}from"@hotwired/stimulus";function o(t,s){let i;return(...a)=>{clearTimeout(i),i=setTimeout((()=>{t.apply(this,a)}),s)}}const s=class e extends t{initialize(){this.save=this.save.bind(this)}connect(){this.delayValue>0&&(this.save=o(this.save,this.delayValue))}save(){this.element.requestSubmit()}};s.values={delay:{type:Number,default:150}};let i=s;export{i as default};

