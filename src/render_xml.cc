#include <stdio.h>
#include <unistd.h>
#include <iostream>
#include <string>

#include "xsl_processor.hh"

using namespace std;

int
main(int argc, char* argv[])
{
  if (argc < 2) {
    printf("usage: %s <xsl_file>\n", argv[0]);
    printf("       (takes XML from stdin)\n"); 
    exit(1);
  }

  char buf[2048];
  string xml_str = "";
  while (fgets(buf, 2048, stdin) != NULL) {
    xml_str += buf;
  }
  
  string xsl_file(argv[1]);
  list<pair<string,string> > listParams;
  XSLProcessor xsl_processor(false);
  cout << xsl_processor.transform(xml_str, xsl_file, listParams) << endl;

  exit(0);
}
