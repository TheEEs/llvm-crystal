require "llvm"
LLVM.init_x86
context = LLVM::Context.new
mod = context.new_module("my module")
execution_engine = LLVM::JITCompiler.new mod
fpm = mod.new_function_pass_manager
LLVM::PassManagerBuilder.new.populate fpm

fun my_print(string : Int32)
    puts string
end

fun raise_exception 
    raise "Exception raised"
end

# this is LLVM IR for the following function
# def main 
#   i = 0
#   while i < 0
#       puts i
#   i += 1
# end

main = mod.functions.add "main", Array(LLVM::Type).new, context.int32 do |function| 
    builder = context.new_builder
    my_print = mod.functions.add "my_print", [context.void_pointer], context.void

    top_level_block = function.basic_blocks.append
    while_condition_block = function.basic_blocks.append 
    while_body_block  = function.basic_blocks.append
    bottom_level_block = function.basic_blocks.append

    builder.position_at_end top_level_block
    i_location = builder.alloca(context.int32)
    builder.store(context.int32.const_int(0),i_location)
    builder.br while_condition_block

    builder.position_at_end while_condition_block
    i_value = builder.load(i_location)
    i_less_than_10 = builder.icmp LLVM::IntPredicate::SLT, i_value, context.int32.const_int(20)
    builder.cond(i_less_than_10,while_body_block,bottom_level_block)

    builder.position_at_end while_body_block
    builder.call my_print, i_value
    new_i = builder.add i_value, context.int32.const_int(1)
    builder.store(new_i, i_location)
    builder.br while_condition_block

    builder.position_at_end bottom_level_block
    builder.ret(i_value)
end

fpm.run do |runner|
    runner.run main 
end

execution_engine.run_function(main,context)
