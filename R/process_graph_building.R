# definitions ----

# Graph ====
#' Graph object
#' 
#' This class represents an openEO process graph - which is generally denoted as field `process_graph` 
#' in the exchange objects of the API. The graph consists of [ProcessNode()]s and optional 
#' [ProcessGraphParameter()] (former variables). The explicit creation of a Graph is usually not 
#' required and discouraged, because this will be handled automatically. 
#' 
#' In terms of the openEO API the process graph is the technical description of a process. To create a
#' user-defined process it requires a process graph and additional meta data. The process graph is not
#' accepted at any openEO endpoint directly. Therefore, it has to be wrapped in a [Process()] 
#' object. Use [as.Process()] in those cases. It is similarly handled in other functions of 
#' this package.
#' 
#' 
#' @name Graph
#' @return Object of [R6::R6Class()] with methods for building an openEO process graph
#' 
#' @field data a named list of collection ids or process graph parameters depending on the context
#' @section Methods:
#' \describe{
#'    \item{`$new(final_node=NULL)`}{The object creator created from processes and available data.}
#'    \item{`$getNodes()`}{a function to return a list of created [ProcessNode()]s for this graph}
#'    \item{`$serialize()`}{creates a list representation of the graph by recursively calling `$serialize`} 
#'    \item{`$validate()`}{runs through the nodes and checks the validity of its argument values}
#'    \item{`$getNode(node_id)`}{searches and returns a node from within the graph referenced by its node id}
#'    \item{`$addNode(node)`}{adds a [ProcessNode()] to the graph}
#'    \item{`$removeNode(node_id)`}{removes a process node from the graph}
#'    \item{`$getFinalNode()`}{gets the result process node of a process graph}
#'    \item{`$setFinalNode(node)`}{sets the result process node by node id or a ProcessNode}
#'    \item{`$getVariables()`}{creates a named list of the defined variables of a process graph}
#'    \item{`$setVariables(list_of_vars)`}{sets the [ProcessGraphParameter()] ( former variables) of graph}
#' }
#' @section Arguments:
#' \describe{
#'    \item{`final_node`}{optional, the final node (end node) that was used to create a graph}
#'    \item{`node_id`}{the id of a process node}
#'    \item{`node`}{process node or  its node id}
#'    \item{`parameter`}{the name of a parameter in a process}
#'    \item{`value`}{the value to be set for a parameter of a particular process}
#'    \item{`id` or `variable_id`}{the variable id}
#'    \item{`description`}{a description field for a variable}
#'    \item{`type`}{the type of variable, default 'string'}
#'    \item{`default`}{optional default value to be set for a variable}
#' }
NULL

Graph = R6Class(
  "Graph",
  public = list(

    initialize = function(final_node=NULL) {
      tryCatch({
        
        if (is.null(final_node)) {
          stop("The final node (endpoint of the graph) has to be set.")
        }
          
        if ("ProcessNode" %in% class(final_node)) {
          node_list = .final_node_serializer(final_node)
          private$nodes=unname(node_list)
          private$final_node_id = final_node$getNodeId()
          tryCatch({
            private$variables = variables(final_node)
          }, error = function(e) {
            
          })
          
        } else {
          stop("The final node has to be a ProcessNode.")
        }
        
        invisible(self)
      }, error = .capturedErrorToMessage)
    },
    
    getNodes = function() {
      return(private$nodes)
    },
    serialize = function() {
      result = lapply(private$nodes, function(node) {
        return(node$serialize())
      })
      names(result) = private$getNodeIds()
      
      result[[self$getFinalNode()$getNodeId()]]$result = TRUE
      
      return(result)
    },
    
    validate = function() {
      tryCatch({
        # for each process node call their processes parameters validate function
        results = unname(unlist(lapply(private$nodes, function(node) {
          node$validate()
        })))
        
        
        if(is.null(results)) {
          return(TRUE)
        } else {
          return(results)
        }
        
      }, error = function(e){
        message(e$message)
      })
    },
    
    getNode = function (node_id) {
      private$assertNodeExists(node_id)
      return(private$nodes[[which(private$getNodeIds() == node_id)]])
    },
    addNode = function(node) {
      if (!"ProcessNode" %in% class(node)) stop("Input object is no ProcessNode")
      private$nodes = c(private$nodes,node)
    },
    
    removeNode = function(node_id) {
      private$assertNodeExists(node_id)
      private$nodes[[which(private$getNodeIds() == node_id)]] = NULL
      
      return(TRUE)
    },
    
    getFinalNode = function() {
      if (length(private$final_node_id) == 0) {
        message("No final node set in this graph.")
        invisible(NULL)
      } else {
        return(private$nodes[[which(private$getNodeIds() == private$final_node_id)[1]]])
      }
      
      
    },
    setFinalNode = function(node) {
      if ("ProcessNode" %in% class(node)) {
        node = node$getNodeId()
      }
      if (is.null(node) || !is.character(node)) {
        message("Node ID is not a character / string.")
        return(FALSE)
      }
      private$assertNodeExists(node_id = node)
      
      private$final_node_id = node
      return(TRUE)
    },
    getVariables = function() {
      return(unique(private$variables))
    },
    setVariables = function(list_of_vars) {
      private$variables=list_of_vars
      invisible(self)
    }
  ),
  private = list(
    nodes = list(),
    variables = list(),
    final_node_id = character(),
    
    assertNodeExists = function(node_id) {
      if (! node_id %in% private$getNodeIds()) stop(paste0("Cannot find node with id '",node_id,"' in this graph."))
    },
    
    getNodeIds = function() {
      return(sapply(private$nodes, function(node)node$getNodeId()))
    }
  )
)

#'@export
setOldClass(c("Graph","R6"))


# Process ====
#' Process object
#' 
#' This object reflects a process offered by an openEO service in order to load and manipulate data collections. It will be created 
#' with the information of a received JSON object for a single process, after the arguments of the process have been translated 
#' into [Argument()] objects.
#' 
#' @name Process
#' 
#' @return Object of [R6::R6Class()] with methods for storing meta data of back-end processes and user assigned data
#' 
#' @field parameters - a named list of Argument objects
#' @field isUserDefined logical - depending if the process is offered by the openEO service or if it was user defined
#' 
#' @section Methods:
#' \describe{
#'    \item{$new(id,parameters,description=character(), summary = character(), parameter_order=character(),returns)}{}
#'    \item{$getId()}{returns the id of a process which was defined on the back-end}
#'    \item{$getParameters()}{returns a named list of arguments}
#'    \item{$getReturns()}{returns the schema for the return type as list}
#'    \item{$getFormals()}{returns the function formals for this process - usually a named vector of the specified default values, but NA where no default value was specified}
#'    \item{$setId(id)}{sets the id of a process}
#'    \item{$setSummary(summary)}{sets the summary text}
#'    \item{$setDescription(description)}{sets the description text}
#'    \item{$getParameter(name)}{returns the Argument object with the provided name}
#'    \item{$getProcessGraph()}{returns the ProcessGraph to which this Process belongs}
#'    \item{$setProcessGraph(process_graph)}{sets the ProcessGraph to which this Process belongs}
#'    \item{$validate()}{validates the processes argument values}
#'    \item{$serialize()}{serializes the process - mainly used as primary serialization for a [ProcessNode()]}
#'    \item{$getCharacteristics()}{select all non functions of the private area, to be used when copying process 
#'    information into a process node}
#' }
#' @section Arguments:
#' \describe{
#'    \item{id}{process id from the back-end}
#'    \item{parameters}{a list of Argument objects}
#'    \item{description}{the process description}
#'    \item{summary}{the summary of a process}
#'    \item{returns}{the returns part of the process definition or an already evaluated parameter}
#'    \item{name}{a parameter name}
#'    \item{value}{the value for a parameter or the description text}
#' }
NULL

Process = R6Class(
  "Process",
  public=list(
    initialize = function(id=character(),description=character(), summary = character(),parameters = list(),returns = list(),process_graph=NULL) {
      private$id = id
      private$description = description
      private$summary=summary
      if (length(process_graph) > 0) {
        self$setProcessGraph(process_graph = process_graph)
      } else {
        if (! (is.list(parameters))) stop("Parameters are not provided as list")
        
        # iterate over all the parameter objects and extract their name
        parameter_names = sapply(parameters, function(p) {
          if (is.list(p)) {
            # in case there was a any of parameter
            p = p[[1]]
          }
          
          p$getName()
        })
        names(parameters) = parameter_names
        
        
        private$.parameters = parameters
        class(private$.parameters) = "ArgumentList"
        
        # case returns as list(schema=list())
        if (is.list(returns) && "schema" %in% names(returns)) {
          private$returns = parameterFromJson(param_def = returns)  
        } else {
          private$returns = returns
        }
      }
      
      return(self)
    },
    
    getId = function() {
      return(private$id)
    },
    
    getParameters = function() {
      return(private$.parameters)
    },
    
    getReturns = function() {
        return(private$returns)
    },
    
    getFormals = function() {
      if (length(self$parameters) == 0) return(list())
      
      result = as.list(rep(NA,length(self$parameters)))
      
      # set also default values
      
      for (i in 1:length(self$parameters)) {
        
        default_value = self$parameters[[i]]$getDefault()

        if (!is.null(default_value)) {
          result[[i]] = default_value
        }
        # otherwise leave it as NA
      }
      
      
      names(result) = sapply(self$parameters, function(param)param$getName())
      
      return(result)
    },
    setId = function(id) {
      if (!is.null(id)) {
        private$id = id
      }
    },
    setDescription = function(description) {
      if (!is.null(description)) {
        private$description = description
      }
    },
    setSummary = function(summary) {
      if (!is.null(summary)) {
        private$summary = summary
      }
    },
    getParameter = function(name) {
      if (!name %in% names(self$parameters)) stop("Cannot find parameter")
      
      return(self$parameters[[name]])
    },
    getProcessGraph = function() {
      return(private$process_graph)
    },
    setProcessGraph = function(process_graph) {
      if (length(process_graph) > 0) {
        if (any(c("ProcessNode","function") %in% class(process_graph))) {
          private$process_graph = as(process_graph,"Graph")
        } else if ("Graph" %in% class(process_graph)) {
          private$process_graph = process_graph
        } else if (is.list(process_graph) || "Json_Graph" %in% class(process_graph)){
          # when we read it from JSON basically 
          private$process_graph = parse_graph(json=process_graph)
        }

        if (length(private$process_graph) > 0) {
          private$.parameters = private$process_graph$getVariables()
          names(private$.parameters) = sapply(private$.parameters, function(param) param$getName())
          
          class(private$.parameters) = "ArgumentList"
          
          private$returns = private$process_graph$getFinalNode()$getReturns()
        }
        
      }
      
      return(invisible(self))
    },
    serialize = function() {
      results = list()
      
      if (length(private$id) == 1) results$id = private$id
      # class(results) = "ProcessInfo"
      
      if (length(private$description)>0) results$description = private$description
      
      if (length(private$summary)>0) results$summary = private$summary
      
      if (self$isUserDefined) {
        results$process_graph
        
        results$process_graph = private$process_graph$serialize()
        # class(results$process_graph) = "Json_Graph"
        
      } 
        
      if (length(self$getParameters()) > 0) {
          serializedArgList = unname(lapply(self$parameters, 
                                     function(param){
                                       param$asParameterInfo()
                                     }))
        
        
        serializedArgList[sapply(serializedArgList,is.null)] = NULL
        
        results$parameters = serializedArgList
                       
      } else {
        results$parameters = list()
      }
      
      if (length(self$getReturns()) > 0) {
        results$returns = self$getReturns()$asParameterInfo()
      } else {
        results$returns = NULL
      }
      
      # clean the optional flag in the result
      if ("optional" %in% names(results$returns)) {
        results$returns[["optional"]] = NULL
      }
      
      return(results)
    },
    validate = function() {
      return(unname(unlist(lapply(self$parameters,function(arg){
        arg$validate()
      }))))
    },
    
    getCharacteristics = function() {
      # select all non functions of the private area, to be used when copying process information into a process node
      fields = sapply(names(private),
                            function(name){
        if(!is.function(private[[name]])) {
          return(name)
        }
      })
      
      return(mget(x=unname(unlist(fields)),envir=private))
    }
  ),
  active = list(
    isUserDefined = function() {
      return(length(private$process_graph) > 0)
    },
    parameters = function(value) {
      if (missing(value)) {
        return(private$.parameters)
      } 
      
    }
  ),
  
  private=list(
    id = character(),
    connection=NULL, # the openeo backend connection to which this graph belongs to
    returns = NULL, # the object that is returend Parameter or Argument
    summary = character(),
    description = character(),
    categories = character(), # probably more than 1 string -> so it is a vector of strings
    process_graph = NULL,
    examples = list(), # a list of objects with arguments: <list>, returns: <value>
    .parameters = list(),
    
    deep_clone = function(name, value) {
      if (name == "process") {
        return(value)
      }
      
      # also check if it is a list of R6 objects
      if (name == ".parameters") {
        
        new_list = list()
        
        for (list_name in names(value)) {
          list_elem = value[[list_name]]
          
          if ("R6" %in% class(list_elem)) {
            list_elem = list_elem$clone(deep=TRUE)
          }
          
          entry = list(list_elem)
          names(entry) = list_name
          new_list = append(new_list,entry)
        }
        
        return(new_list)
        
      }
      
      if (is.environment(value) && !is.null(value$`.__enclos_env__`)) {
        return(value$clone(deep = TRUE))
      }
      
      value
    }
    
    
  )
)

#' @export
setOldClass(c("Process","R6"))

setClass("ArgumentList")

# ProcessNode ====
#' Process Node object
#' 
#' This class inherits all functions and fields from [Process()] and extends it with a node id and a 
#' special serialization function. The ProcessNode is an essential building block of the [Graph()].
#' 
#' @name ProcessNode
#' @section Methods:
#' \describe{
#'    \item{$getNodeId()}{returns the node id}
#'    \item{$setNodeId(id)}{set the node id, which is of interest when [parse_graph()] is executed}
#'    \item{$serializeAsReference()}{during the serialization the process node might be used as a 
#'    reference and this function serializes the process node accordingly}
#' }
#' @section Arguments:
#' \describe{
#'    \item{id}{the node id}
#' }
#' 
#' @importFrom rlang is_na
NULL

ProcessNode = R6Class(
  "ProcessNode",
  inherit = Process,
  public = list(
    
    # initialized in the graph$<function> call  together with is argument values
    initialize = function(node_id=character(),process,graph=NULL) {
      private$node_id = node_id
      
      if (!"Process" %in% class(process)) stop("Process is not of type 'Process'")
      
      if (process$isUserDefined) {
        private$.namespace = "user"
      }
      
      if(length(graph) > 0) {
        private$graph = graph
      }
      
      private$copyAttributes(process)
      
      class(private$.parameters) = "ArgumentList"
      
      return(self)
    },
    
    getNodeId = function() {
      return(private$node_id)
    },
    setNodeId = function(id) {
      private$node_id = id
    },
    serialize = function() {
      results = list(process_id=private$id)
      
      if (length(private$description)>0) results$description = private$description
      
      if (length(private$.namespace) > 0) {
        results$namespace = private$.namespace
      }
      
      if (length(self$getParameters()) > 0) {
          serializedArgList = lapply(self$parameters, 
                                     function(arg){
                                       arg$serialize()
                                     })
        
        serializedArgList[sapply(serializedArgList,is.null)] = NULL
        
        results$arguments = serializedArgList
        
      } else {
        results$arguments = list()
      }
      
      return(results)
    },
    serializeAsReference = function() {
      return(list(
        from_node=private$node_id
      ))
    },
    getGraph = function() {
      return(private$graph)
    },
    setGraph = function(g) {
      private$graph = g
      invisible(self)
    }
  ),
  active = list(
    namespace = function(value) {
      if (missing(value)) {
        return(private$.namespace)
      } else {
        if (!rlang::is_na(value) || (!is.character(value) && !tolower(value) %in% c("user","backend"))) {
          warning("Cannot assign namespace to the process. It has to be NA, 'user' or 'backend'")
        } else {
          private$.namespace = value
          return(invisible(self))
        }
      }
    }
  ),
  
  private = list(
    node_id = character(),
    .namespace = NULL,
    graph = NULL,
    
    copyAttributes = function(process) {
      #extract names that are no function
      tobecopied = process$getCharacteristics()
      
      tobecopied[["description"]] = character()
      
      lapply(names(tobecopied), function(attr_name) {
        assign(x = attr_name, value = tobecopied[[attr_name]],envir = private)
      })
      return()
    }
  )
)

setOldClass(c("ProcessNode","Process","R6"))

.randomNodeId = function(name,n = 1,...) {
  a <- do.call(paste0, replicate(5, sample(LETTERS, n, TRUE), FALSE))
  paste(name,paste0(a, sprintf("%04d", sample(9999, n, TRUE)), sample(LETTERS, n, TRUE)),...)
}

# Extra functions / wrapper ----

#' Converts a JSON openEO graph into an R graph
#' 
#' The function reads and parses a json text and creates a Graph object.
#' 
#' @param con a connected openEO client (optional) otherwise [active_connection()]
#' is used.
#' @param json the json graph in a textual representation or an already parsed list object
#' @param parameters optional parameters
#' @return Graph object
#' @export
parse_graph = function(json, parameters = NULL, con=NULL) {
  tryCatch({
    con = .assure_connection(con)
    processes = processes()
    
    # TODO what to do with "json" being a process node which need to be readded to the node id list?
    
    if (is.list(json)) {
      parsed_json = json
    } else {
      if (!is.character(json)) json = as.character(json)
      
      is_valid = jsonlite::validate(json)
      
      if (!is_valid) {
        message("Invalid JSON object. With the following message:")
        stop(attr(is_valid,"err"))
      }
      
      parsed_json = fromJSON(json, simplifyDataFrame = FALSE)
    }
    
    # use processes id on processes (processes[[id]])
    # substitute values or set values
    # if names(v) contains process_graph, do recursive call parse_graph
    # if names(v) contains from_parameter -> create ProcessGraphParameter
    # if names(v) contains from_node -> look up node_id
    
    graph_definition = parsed_json$process_graph
    
    process_graph_parameters_names = sapply(parsed_json$parameters, function(param) {
      param$name
    })
    
    process_graph_parameters = lapply(parsed_json$parameters,function(param){
      potential_param = parameterFromJson(param)
      p = ProcessGraphParameter$new(name = param$name,
                                    description = param$description)
      
      p$adaptType(list(potential_param))
      # identify nullable and required
      return(p)
    })
    names(process_graph_parameters) = process_graph_parameters_names
    
    if (length(process_graph_parameters) == 0) {
      process_graph_parameters = parameters
    }
    
    node_ids = names(graph_definition)
    process_lookup = lapply(node_ids, function(id) {
      pdef = graph_definition[[id]]
      process_id = pdef$process_id
      if (!process_id %in% names(processes)) stop(paste0("Process '",process_id,"' is not provided by the connected openEO service."))
      
      p = processes[[process_id]]()
      p$setNodeId(id)
      
      
      return(p)
    })
    names(process_lookup) = node_ids
    
    
    lapply(node_ids, function(id) {
      pdef = graph_definition[[id]]
      p = process_lookup[[id]]
      
      # pdef$arguments here
      lapply(names(pdef$arguments),function(name) {
        argument = p$parameters[[name]]
        value = pdef$arguments[[name]]
        
        # if the list is named and contains process graphs treat it as intended for load_collection for example... a process for each entry
        list_of_process_graphs = sapply(value, function(p) {
          "process_graph" %in% names(p)
        })
        if (length(names(value)) > 0 && all(list_of_process_graphs)) {
          params = argument$getProcessGraphParameters()
          names(params) = sapply(params, function(p)p$getName())
          
          property_names = names(value)
          value = lapply(1:length(value), function(index) {
            parse_graph(con=con,json = value[[index]], parameters = params)
          })
          
          names(value) = property_names
        } else if ("process_graph" %in% names(value)) {
          # do subgraph
          if (!"ProcessGraphArgument" %in% class(argument)) stop("Found a process graph in JSON, but parameter is no ProcessGraph.")
          
          params = argument$getProcessGraphParameters()
          names(params) = sapply(params, function(p)p$getName())
          value = parse_graph(con=con,json = value, parameters = c(process_graph_parameters,params))
        } else if ("from_parameter" %in% names(value)) {
          # do lookup for parameters
          parameter_name = value$from_parameter
          
          value = process_graph_parameters[[parameter_name]]
        } else if ("from_node" %in% names(value)) {
          value = process_lookup[[value$from_node]]
        } else if (is.list(value) && length(value) > 0) {
          # iterate through list and look for lists with from_node or from_parameter and replace them with the correct items
          value = lapply(value, function(array_elem) {
            if (is.list(array_elem)) {
              if ("from_node" %in% names(array_elem)) {
                return(process_lookup[[array_elem$from_node]])
              } else if ("from_parameter" %in% names(array_elem)) {
                return(process_graph_parameters[[array_elem$from_parameter]])
              } else {
                return(array_elem)
              }
            } else {
              return(array_elem)
            }
          })
        }
        
        argument$setValue(value)
        
      })
      
      return(p)
    })
    
    #find final node and coerce to graph
    final_node_id = unlist(lapply(node_ids, function(id) {
      pdef = graph_definition[[id]]
      
      if (isTRUE(pdef$result)) {
        return(id)
      } else {
        return(NULL)
      }
    }))
    
    final_node = process_lookup[[final_node_id]]
    
    return(as(final_node,"Graph"))
  }, error = .capturedErrorToMessage)  
}

#' Creates a variable in a process graph
#' 
#' This function creates a variable to be used in the designated process graph with additional optional information.
#' 
#' @param name the name of the variable
#' @param description an optional description of the variable
#' @param type the type of the value that is replaced on runtime, default 'string'
#' @param subtype the subtype of the type (as specified by openEO types)
#' @param default the default value for this variable
#' @return a [ProcessGraphParameter()] object
#' 
#' @export
create_variable = function(name,description=NULL,type=NULL,subtype=NULL,default=NULL) {
    return(ProcessGraphParameter$new(name=name, 
                                     description=description,
                                     type=type,
                                     subtype=subtype,
                                     default=default))
}

#' Lists the defined variables for a graph
#' 
#' The function creates a list of the defined (but not necessarily used) variables of a process graph.
#' 
#' @param x a process graph object or a process node
#' @return a named list of Variables
#' 
#' @importFrom rlang is_na
#' @export
variables = function(x) {
  if ("Graph" %in% class(x)) {
    # get final node
    suppressMessages({
      x = x$getFinalNode()
    })
  }
  
  if (length(x) == 0 || 
      !"ProcessNode" %in% class(x)) stop("No final node defined. Please either set a final node in the graph or pass it into this function.")
  
  # get all the available process nodes of that graph
  used_nodes = .final_node_serializer(x)
  
  variables = lapply(used_nodes,function(node){
    # check all parameter
    node_variables = lapply(node$parameters,function(param) {
      value = param$getValue()
      
      if (length(value) > 0 && (is.environment(value) || !rlang::is_na(value))) {
        if ("Graph" %in% class(value)) {
          return(value$getVariables())
        # } else if ("variable" %in% class(value)) {
        } else if ("ProcessGraphParameter" %in% class(value) && length(value$getProcess()) == 0) {
          return(value)
        } else if (is.list(value)) {
          return(
            lapply(value, function(array_elem) {
              # if ("variable" %in% class(array_elem)) {
              if ("ProcessGraphParameter" %in% class(array_elem) && length(array_elem$getProcess()) == 0) {
                return(array_elem)
              }
              
              return(NULL)
            })
          )
        }
      } 
      
      return(NULL)
    })
    
    return(node_variables)
  })
  variables = unname(unlist(unique(variables)))
  
  # if variables are NULL then there are no unbound variables
  if (is.null(variables)) {
    return(list())
  } else {
    list_of_all_params = unlist(lapply(used_nodes, function(n) {
      # anyof: value is the chosen parameter
      
      params = unname(n$parameters)
      params = lapply(params, function(p) {
        if ("anyOf" %in% class(p)) {
          return(p$getValue())
        } else {
          return(p)
        }
      })
    }))
    
    # find all the parameters where the ProcessGraphParameter a.k.a. variable were set as value
    matches = lapply(variables,function(graph_param) {
      unlist(lapply(list_of_all_params, function(p,n) {
        if (length(p$getValue()) != 0 && !is.list(p$getValue()) && identical(p$getValue(),n)) {
          return(p)
        } else if (length(p$getValue()) != 0 && is.list(p$getValue())) {
          array = p$getValue()
          match = sapply(array, function(p) {
            if (is.null(p)) return(FALSE)
            
            return(identical(p,n))
          })
          
          if (any(match)) {
            return(array[match])
          } else {
            return(NULL)
          }
        } else {
          return(NULL)
        }
      },n=graph_param))
    })
    
    # now find the most picked argument per process graph parameter (p)
    most_probable_types = lapply(matches, function(variable) {
      if (length(variable) == 0) return(list())
      
      # variable is a list
      class_matches = sapply(variable, function(p) {
        class(p)[[1]]
      })
      
      # determine most picked
      unique_types = unique(class_matches)
      counts = sapply(unique_types, function(class) {
        sum(class_matches == class)
      })
      
      
      most_probable = unique_types[which(counts==max(counts,na.rm = TRUE))]
      
      # find first occurence in class_matches to get an index
      # use the index on variable (list) to get the parameter, from which we will later obtain the schema
      var = variable[class_matches == most_probable][1]
      
      
      return(var)
    })
    
    # at this point we don't have a check, whether or not there are conflicts in setting the process graph parameter (e.g. different types)
    for (i in 1:length(variables)) {
      if (! "Argument" %in% class(variables[[i]])) {
        warning("Can't translate process graph parameter into R-object")
      }
      variables[[i]]$adaptType(most_probable_types[[i]])
      
    }
    
    return(variables)
  }
}
  
  
#' Removes a variable from the Graph
#' 
#' The function that removes a selected variable from the graph. It is removed from the list of defined 
#' variables that are obtainable with [variables()]. The variables already placed in the graph 
#' won't be deleted, only in the defined variables list.
#' 
#' @param graph a [Graph()] object
#' @param variable a variable id or a variable object
#' @return TRUE
#' @export
remove_variable = function(graph, variable) {
  if ("ProcessNode" %in% class(graph)){
    # final node!
    graph = Graph$new(final_node = graph)
  }
  
  if (!all(c("Graph","R6") %in% class(graph))) stop("Parameter graph is no Graph object")
  
  if (length(variable) == 0) stop("Parameter 'variable' cannot be NULL or empty")
  if (all(c("variable","Argument","R6") == class(variable))) variable = variable$getName()
  
  return(graph$removeVariable(variable_id = variable))
}

.final_node_serializer = function(node,graph=list()) {
  add = list(node)
  names(add) = node$getNodeId()

  paramValues = unname(unlist(lapply(node$parameters,function(param) {
    if ("anyOf" %in% class(param)) {
      param = param$getValue()
    }
    
    if (!is.null(param)) {
      return(param$getValue())
    } else {
      return(NA)
    }
  })))
  
  nodeSelectors = sapply(paramValues,function(v) {
    "ProcessNode" %in% class(v)
  })
  selectedNodes = paramValues[nodeSelectors]
  
  if(length(selectedNodes)==0) {
    return(add)
  } else {
    temp = unlist(c(lapply(selectedNodes,function(node){
      .final_node_serializer(node,graph)
    }),add))
    
    unames = unique(names(temp))
    
    return(temp[unames])
  } 
}

# this function will be used when transforming a function into a submitable process graph (user defined process), it will
# not set and evaluate process graph parameters
#
# process_collection: the object from processes()
.function_to_graph = function(value, process_collection) {
  if (!is.function(value)) stop("Value is no function")
  if (missing(process_collection) || length(process_collection) == 0) process_collection = processes()
  
  process_graph_parameter = lapply(names(formals(value)), function(param_name) {
    v = ProcessGraphParameter$new(name=param_name)
    
    return(v)
  })
  # if value is a function -> then make a call with the function and a suitable ProcessGraphParameter
  
  # make call
  # we need the assignment since we might have basic mathematical operation that are overloaded
  final_node = do.call(value,args = process_graph_parameter)
  
  # assign new graph as value
  value = Graph$new(final_node = final_node)
  
  return(value)

}

#' @export
`$.ArgumentList` = function(x, name) {
  val = unclass(x)[[name]]$getValue()
  if ("Argument" %in% class(val)) return(val$getValue())
  else return(val)
}

#' @export
`$<-.ArgumentList` = function(x, name, value) {
  unclass(x)[[name]]$setValue(value)
}

#' @export
`[<-.ArgumentList` = function(x, i, value) {
  unclass(x)[[i]]$setValue(value)
}

#' @export
`[[<-.ArgumentList` = function(x, i, value) {
  unclass(x)[[i]]$setValue(value)
}
