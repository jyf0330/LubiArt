import { FileBlob, SpreadsheetFile } from "@oai/artifact-tool";

const workbookPath = "/Users/ywh/Documents/ysbzs/xlsx/ysbzs_master.xlsx";
const input = await FileBlob.load(workbookPath);
const workbook = await SpreadsheetFile.importXlsx(input);
const result = await workbook.inspect({
  kind: "region",
  sheetId: "PETS",
  range: "A1:V12",
  include: "values,formulas",
  maxChars: 20000,
  tableMaxRows: 12,
  tableMaxCols: 22,
  tableMaxCellChars: 160,
});
console.log(result.ndjson);
