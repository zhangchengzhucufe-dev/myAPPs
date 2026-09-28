/* ==== SEED_IMPORT_V2 单词种子（来自 wordsToImport 截图 OCR，双录入交叉核验） ==== */
const SEED_V2 = __SEED__;
(function seedImportV2(){
  try{
    if(localStorage.getItem(LS + '.seed2')) return;
    let n = 0;
    SEED_V2.forEach(function(pair){ if(!findWord(pair[0])){ addWord(pair[0], pair[1]); n++; } });
    if(n){ save(); toast('已从截图词库导入 ' + n + ' 个新单词'); }
    localStorage.setItem(LS + '.seed2', '1');
  }catch(_){}
})();
