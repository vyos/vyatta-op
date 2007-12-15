/**
 * Module: xsl_processor.hh
 *
 * Author: Michael Larson
 * Date: 2005
 */
#ifndef __XSL_PROCESSOR_HH__
#define __XSL_PROCESSOR_HH__

#include <list>
#include <string>
#include <utility>


class XSLProcessor
{
public:
  XSLProcessor(bool debug);
  ~XSLProcessor();

  std::string
  transform(const std::string &input, const std::string &xsl, const std::list<std::pair<std::string, std::string> > & listParams);
  
private:
  bool _debug;
};

#endif //__XSL_PROCESSOR_HH__
