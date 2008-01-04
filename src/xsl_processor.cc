/**
 * Module: xsl_processor.cc
 *
 * Author: Michael Larson
 * Date: 2005
 */
#include <string>
#include <iostream>
#include <sablot.h>
#include "xsl_processor.hh"

using namespace std;

/**
 *
 **/
XSLProcessor::XSLProcessor(bool debug) : _debug(debug)
{

}

/**
 *
 **/
XSLProcessor::~XSLProcessor()
{

}

/**
 *
 **/
std::string
XSLProcessor::transform(const string &input, const string &xsl, const list<pair<string,string> > & listParams)
{
  if (_debug) {
    cout << "input to xsl processor: " << endl << input << endl << xsl << endl;
  }

  //for now we'll dump this into a file, but this will have to change soon.
  string formatted_output;

  //example below from  http://www.gingerall.org/ga/html/sablot/sparse-frameset.html
  SablotSituation S;
  SablotHandle proc;
  SDOM_Document xml;
  
  SablotCreateSituation(&S);

  SablotParseBuffer(S, input.c_str(), &xml);

  SablotCreateProcessorForSituation(S, &proc);
  SablotAddArgTree(S, proc, "data", xml);
  list<pair<string, string> >::const_iterator i = listParams.begin();
  list<pair<string, string> >::const_iterator iEnd = listParams.end();
  while (i != iEnd) {
    SablotAddParam(S, proc, i->first.c_str(), i->second.c_str());
    i++;
  }
  SablotRunProcessorGen(S, proc, xsl.c_str(), "arg:/data", "arg:/out");
  
  char *result;
  SablotGetResultArg(proc, "arg:/out", &result);
  
  formatted_output = result;
  
  //now strip away the first line
  int pos = formatted_output.find("\n");
  formatted_output = formatted_output.substr(pos + 1, formatted_output.length() - pos - 1);
  
  SablotFree(result);
  SablotDestroyProcessor(proc);
  SablotDestroySituation(S);

  return formatted_output;
}
