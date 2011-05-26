function field(id) {
    var fields = new Array("genres","artists","albums","by_date");
    for (i=0; i < fields.length; i++) {
        if (fields[i] == id) {
            document.getElementById(fields[i]).style.display='block';
        } else {
            document.getElementById(fields[i]).style.display='none';
        }
    }
}
